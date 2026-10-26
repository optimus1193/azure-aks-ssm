# azure-aks-platform

The **hub** for AKS provisioning. The platform team owns all the Terraform here: modules, root stacks, provider and backend setup, the pipeline, naming and tagging rules, defaults, and guardrails. It is the Azure counterpart of `aks-ssm` (the EKS stack).

Customers (**spokes**) don't write Terraform. A spoke repo ([`azure-aks-customer`](https://github.com/my-org/azure-aks-customer) is the template) holds only:

```
environments/<env>/config.yaml     what to provision, the feature toggles, and mode: create | destroy
environments/<env>/rbac/*.yaml     optional Kubernetes RBAC manifests
azure-pipelines.yml                short Azure DevOps pipeline that calls pipelines/provision.yml (primary)
.github/workflows/aks.yml          short caller of this repo's reusable GitHub workflow (create mode only)
```

## How a run works

### Azure DevOps (primary)

```
spoke commit to main / PR
  └─ azure-pipelines.yml  ──template──▶  azure-aks-platform/pipelines/provision.yml  (repository resource @ refs/tags/<tag>)
       Plan_<env>     checkout spoke + this repo, install Terraform + kubelogin
                      scripts/check-config.sh          → mode (create | destroy)
                      scripts/run-environment.sh plan  → plan, or destroy plan; records which stacks change
       Apply_<env>    mode create,  main only, plan has changes; environment <env>
                      scripts/run-environment.sh apply → 01-cluster, then 02-platform
       Destroy_<env>  mode destroy, main only, plan has changes; ManualValidation + environment <env>-destroy
                      scripts/run-environment.sh apply → destroy 02-platform, then 01-cluster
```

Authentication is an Azure Resource Manager service connection with workload identity federation. Every Terraform step runs inside `AzureCLI@2`, so the azurerm backend, the provider and kubelogin (`azurecli` mode) all use that session.

### GitHub Actions

```
spoke PR / merge
  └─ .github/workflows/aks.yml  ──uses──▶  azure-aks-platform/.github/workflows/provision.yml@<tag>
                                              ├─ checkout spoke config + this repo at <tag>
                                              ├─ azure/login (OIDC), install kubelogin
                                              ├─ scripts/run-stack.sh 01-cluster  <plan|apply> config.yaml
                                              └─ scripts/run-stack.sh 02-platform <plan|apply> config.yaml
```

This path supports `mode: create` only; it fails if a config is in `destroy` mode. Pull requests plan. A merge to `main` applies through the GitHub environment `<env>`, so its required reviewers are the approval gate (plans use `<env>-plan`). State is stored in the customer's storage account under `<org>/<repo>/<env>/<stage>.tfstate`.

## Layout

```
stacks/                  root modules the pipeline runs; the only entry points
  01-cluster/            Azure resources (azurerm)
  02-platform/           everything inside Kubernetes (helm, kubernetes, kubectl)
modules/
  config/                reads config.yaml: naming, mandatory tags, feature defaults, key and required-value checks
  aks-cluster/           AKS, identities, KMS key vault, Log Analytics, Container Insights, Managed Prometheus, RBAC
  node-provisioning/     Karpenter NodePool + AKSNodeClass for Node Auto Provisioning
  platform-addons/       Traefik, ArgoCD (core), Kyverno + Policy Reporter, Reloader, RBAC manifests (optional)
  workload-identity/     Managed identity + federated credential for one service account (IRSA equivalent)
scripts/
  check-config.sh        validate config.yaml with modules/config (no Azure access) and print its mode
  run-environment.sh     both stacks in the order the mode needs (plan | apply)
  run-stack.sh           init (backend per customer environment) + plan/apply/plan-destroy/destroy of one stack
pipelines/
  provision.yml          Azure DevOps stages template that spokes call (Plan, Apply, Destroy)
  variables.yml, steps/setup.yml   shared variables and setup steps for it
.github/workflows/provision.yml   reusable GitHub workflow that spokes call (create mode only)
```

## Create / destroy toggle (`mode`)

`mode` is a top-level key in the spoke's `config.yaml`. It is `create` when omitted.

| `mode` | Plan stage | On `main`, after approval |
|---|---|---|
| `create` | plan 01-cluster, then 02-platform | `Apply_<env>`: apply them in that order |
| `destroy` | destroy plan of 02-platform, then 01-cluster | `Destroy_<env>`: destroy them in that order |

Guardrails on destroy:

- **`features.delete_lock` must be `false`.** Terraform deletes the management lock itself during a destroy, so the lock alone wouldn't stop the pipeline. `modules/config` therefore refuses `mode: destroy` while the lock is on (the default in prod). Setting both keys is an explicit, reviewable statement in the commit.
- **Two approvals.** `ManualValidation@1` in a server job comes first. It is part of the template, so a destroy still waits for a person even if the ADO environment `<env>-destroy` was auto-created with no checks. The person who started the run can't approve it. The deployment job on `<env>-destroy` comes next, with its own approvals.
- **The approved mode must still match.** The apply and destroy jobs re-read `config.yaml` with `EXPECTED_MODE` set. A run approved for `create` can't destroy, and the reverse is also true.
- **Only changes are gated.** Apply and Destroy are skipped when the plan has no changes. An already-destroyed environment left in `destroy` mode is a no-op, and a commit to one environment doesn't ask for approvals on another.

Destroy removes only what the stacks created. The VNet, the state storage account, the platform Key Vault and the ACR are inputs, so they stay. The KMS key vault has purge protection, so after a destroy it stays soft-deleted for 90 days. A later `create` makes a new one with a fresh random suffix. If anything outside Terraform added resources to the cluster resource group, `prevent_deletion_if_contains_resources` stops the resource group delete and names them. Remove them, then re-run.

## What the hub enforces

- **Core offerings:** Traefik and ArgoCD are always installed. They are not in the feature list, and setting `features.traefik` or `features.argocd` fails the plan. `platform.argocd` and `platform.platform_key_vault_id` are required. To make another add-on core, remove it from `default_features` in `modules/config/main.tf`, delete its `enable_*` variable and `count`, and add a `moved` block (see `modules/platform-addons/moved.tf`).
- **Naming:** `aks-<name>-<environment>` and `rg-aks-<name>-<environment>`, unless `cluster.name` / `cluster.resource_group_name` are set.
- **Mandatory tags:** `Environment`, `Application`, `Created_By` and `Managed_By` are added on top of the customer's `tags`. The hub's values win.
- **Strict config:** unknown keys (typos) and missing required keys fail the plan and name the key. Values are type-checked and validated by the module variables.
- **Defaults:** a key the customer leaves out falls back to the module default, so changing a default here changes every spoke when it upgrades to that release.

## Config reference (`environments/<env>/config.yaml`)

Required: `name`, `environment`, `subscription_id`, `location`, `cluster.kubernetes_version`, `cluster.vnet_subnet_id`, `platform.platform_key_vault_id`, `platform.argocd.domain`.

| Section | Keys |
|---|---|
| top level | `mode` (`create` default, or `destroy`), `name`, `environment` (dev/test/uat/preprod/prod), `subscription_id`, `location`, `tags`, `features`, `cluster`, `platform` |
| `features` | `node_auto_provisioning`, `kms_etcd_encryption`, `defender`, `azure_policy`, `key_vault_secrets_provider`, `container_insights`, `managed_prometheus` (default `true`); `delete_lock` (default `true` in prod only); `keda`, `vpa` (default `false`); `kyverno`, `reloader`, `rbac_manifests` (default `true`) |
| `cluster` | Same names as the [aks-cluster variables](modules/aks-cluster/variables.tf), minus the `enable_*` toggles (those are in `features`): `name`, `resource_group_name`, `create_resource_group`, `node_resource_group_name`, `kubernetes_version`, `sku_tier`, `vnet_subnet_id`, `additional_network_contributor_scopes`, `network`, `private_dns_zone_id`, `private_cluster_public_fqdn_enabled`, `system_node_pool`, `user_node_pools`, `host_encryption_enabled`, `automatic_upgrade_channel`, `node_os_upgrade_channel`, `maintenance_window`, `image_cleaner_interval_hours`, `admin_group_object_ids`, `cluster_role_assignments`, `grant_deployer_cluster_admin`, `acr_ids`, `run_command_enabled`, `kms_key_vault_network_access`, `kms_private_endpoint`, `secret_rotation_interval`, `storage_drivers`, `log_analytics_workspace_id`, `log_retention_in_days`, `log_daily_quota_gb`, `control_plane_log_categories`, `container_insights` |
| `platform` | Same names as the [platform-addons variables](modules/platform-addons/variables.tf): `platform_key_vault_id`, `helm_repository_override`, `chart_versions`, `ingress_class_name`, `traefik`, `argocd`, `kyverno_dashboard_domain`; plus `node_pools` ([node-provisioning](modules/node-provisioning/variables.tf)) |

To expose a new module option to customers, add it in three places: the module variable, the stack's module call (`try(local.c.<key>, null)`), and `allowed_keys` in `modules/config/main.tf`. Module variables with a default are `nullable = false`, so an omitted key gets the default.

### Why two stacks

The EKS repo configures the `kubernetes`, `helm` and `kubectl` providers inside the cluster module, in the same apply that creates the cluster. A `time_sleep 180s` covers the race. That pattern breaks module `count`/`depends_on` and causes errors on replace or destroy. Here, `01-cluster` creates the cluster. `02-platform` then reads it through a data source, so the providers get real values at plan time and no sleep is needed. Both stacks get the cluster name from the same config, so no remote state lookup is needed. On a brand-new environment, a plan-only run skips 02-platform until 01-cluster has been applied.

## Onboarding a spoke (Azure DevOps)

1. Create the customer repo from `azure-aks-customer` and fill in `environments/<env>/config.yaml`. Keep `mode: create`.
2. Create an Azure Resource Manager service connection per environment, using **workload identity federation**. Grant its identity the same roles as in step 3 of the GitHub list below.
3. Give the spoke pipeline access to this repo: on `azure-aks-platform`, allow the spoke project's build service to read the repo. Then check that the `ref:` in `azure-pipelines.yml` is a release tag. For a GitHub-hosted platform repo, use `type: github` with a GitHub service connection.
4. Provide an agent pool that can reach the private API server: self-hosted agents, or a Managed DevOps Pool injected into the VNet or a peered one. Agents need bash, Azure CLI, curl, unzip and sha256sum. The pipeline installs Terraform and kubelogin.
5. **Before the first run**, create two ADO environments. If they don't exist, ADO creates them on first use with no checks.
   - `<env>`: approvals for applies, plus an Exclusive Lock check.
   - `<env>-destroy`: stricter approvals for destroys, plus an Exclusive Lock check.
6. Authorize the pipeline to use the service connection, agent pool and environments. If the repo is in Azure Repos, add a Build Validation branch policy on `main`, so that pull requests run the plan.
7. Set `destroyApprovers` in `azure-pipelines.yml` to the group allowed to confirm destroys.

Moving a spoke from GitHub Actions to ADO: set `stateKeyPrefix` to the key the workflow used (`<org>/<repo>/<env>`). Otherwise the first plan would create a second copy of the environment. Then disable the GitHub workflow.

## Onboarding a spoke (GitHub Actions)

1. Create the customer repo from `azure-aks-customer` and fill in `environments/<env>/config.yaml`.
2. Create an Entra app registration (or user-assigned identity) for the pipeline, with federated credentials for `repo:<org>/<repo>:environment:<env>` and `repo:<org>/<repo>:environment:<env>-plan`.
3. Grant it Contributor + User Access Administrator on the subscription (or the cluster resource group), Network Contributor on the VNet, Storage Blob Data Contributor on the state storage account, and Key Vault Secrets User on the platform Key Vault.
4. Set the repo secrets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID`. Add `PLATFORM_REPO_TOKEN` if the customer's workflows can't read this repo.
5. Provide a self-hosted runner that can reach the private API server (in the VNet or a peered one). It needs Azure CLI and bash; the workflow installs Terraform and kubelogin.
6. Create the GitHub environment `<env>` with required reviewers.

## Prerequisites per spoke

1. **Network reach to the private API server** from the runner. This replaces the SSM bastion. `az aks command invoke` is available as a break-glass option when `cluster.run_command_enabled: true`.
2. **Existing resources:** VNet and subnets, a Terraform state storage account (container `tfstate`), and a platform Key Vault containing:
   - `argocd-admin-password`: plain-text value
   - `GithubCreds`: JSON `{"username": "...", "password": "..."}`
3. **UDR egress only** (`network.outbound_type: userDefinedRouting`): the firewall must allow the [AKS required outbound rules](https://learn.microsoft.com/azure/aks/outbound-rules-control-egress).

## Releasing

Spokes pin a tag, so a change reaches them only through a tag. In ADO it is the single `ref: refs/tags/<tag>` on the `platform` repository resource. In GitHub it is both `uses: ...provision.yml@<tag>` and `platform_version: <tag>`.

1. Run the tests (below), merge to `main`, then tag with semver: `git tag v1.1.0 && git push origin v1.1.0`.
2. **Major** bump when a customer has to change their config or the plan replaces resources (renamed or removed keys, new required keys, an optional add-on made core). **Minor** for new options or chart bumps. **Patch** for fixes.
3. Write release notes listing config changes, so customers know what to edit when they bump the tag.

## Tests

Plan-only tests with mocked providers, so no Azure access is needed. They need Terraform >= 1.11.

```bash
for d in modules/config stacks/01-cluster stacks/02-platform; do
  terraform -chdir=$d init -backend=false && terraform -chdir=$d test
done
```

Fixtures are in `modules/config/tests/fixtures/`. `valid.yaml` mirrors the customer template; keep the two in sync.

## Running locally (platform team)

```bash
az login
export TF_STATE_RESOURCE_GROUP=rg-tfstate-prod TF_STATE_STORAGE_ACCOUNT=sttfstateprod001
export TF_STATE_KEY_PREFIX=my-org/azure-aks-customer/prod
scripts/run-stack.sh 01-cluster plan ../azure-aks-customer/environments/prod/config.yaml
scripts/run-environment.sh plan ../azure-aks-customer/environments/prod/config.yaml   # both stacks, follows mode
```

## EKS → AKS mapping

| aks-ssm (EKS) | azure-aks-platform (AKS) |
|---|---|
| `aws_eks_cluster`, private endpoint | `azurerm_kubernetes_cluster` with `private_cluster_enabled`, `sku_tier = Standard` (SLA) |
| KMS key + `encryption_config` | Key Vault key + `key_management_service` (etcd KMS) |
| Control plane IAM role | User-assigned identity + Network Contributor on node subnets |
| `aws-auth` ConfigMap with hard-coded roles | Entra ID + Azure RBAC: `admin_group_object_ids`, `cluster_role_assignments` (supports namespace scope), local accounts disabled |
| OIDC provider + `irsa` module | `oidc_issuer_enabled` + `workload_identity_enabled` + `modules/workload-identity` |
| Fargate profile for Karpenter | System node pool tainted `CriticalAddonsOnly` |
| Self-hosted Karpenter (helm, IAM, subnet tags) | Node Auto Provisioning (managed Karpenter), `modules/node-provisioning` |
| EC2NodeClass AL2023 + custom AMI | AKSNodeClass `AzureLinux`, auto-patched via `node_os_upgrade_channel` |
| vpc-cni + `enableNetworkPolicy` | Azure CNI Overlay + Cilium dataplane and network policy |
| kube-proxy, metrics-server add-ons | Managed by AKS |
| EBS / EFS CSI charts | `storage_profile` disk / file / blob drivers |
| Secrets Store CSI + AWS provider | `key_vault_secrets_provider` with rotation |
| ALB controller + Traefik with NLB target groups | Traefik on an internal Azure Standard LB (service annotations) |
| CloudWatch observability + Fluent Bit ConfigMap | Container Insights (ContainerLogV2, namespace filtering) |
| `null_resource` log retention polling | `retention_in_days` on the Log Analytics workspace |
| `enabled_cluster_log_types` | `control_plane_log_categories` → diagnostic setting (resource-specific tables) |
| Enhanced container insights | Managed Prometheus (Azure Monitor workspace) |
| Kubelet image GC tweak in userdata | Image Cleaner |
| eks-resource-protection | `CanNotDelete` management lock (`features.delete_lock`) |
| Secrets Manager (ArgoCD password, Git creds) | Key Vault secrets (`platform_key_vault_id`) |
| Private ECR as helm OCI repo | `helm_repository_override` (e.g. ACR) |
| `helm-versions.tf` coalesce per K8s version | One `chart_versions` map, overridable per environment |
| `count`-indexed RBAC manifests | `for_each` keyed by `kind/namespace/name` |
| `random_id` suffix on cluster name | Deterministic names (AKS names are resource-group scoped) |

### Not ported on purpose

- **Trellix / Cynet installed from EC2 userdata.** AKS does not support custom userdata. Microsoft Defender for Containers is enabled instead. If those agents are mandatory, run them as a DaemonSet from GitOps.
- **ingress-nginx.** The project is retired, so Traefik is the ingress controller.
- **Kubernetes Dashboard.** The project is archived. Use the AKS portal resource view or Headlamp.
- **SonarQube / PostgreSQL.** These are applications, not platform. Deploy them through ArgoCD.

## Operations

- **Kubernetes minor upgrade:** the customer bumps `cluster.kubernetes_version` in `config.yaml` and merges. Patch upgrades and node images are applied automatically in the maintenance window. The auto-upgrade channel is limited to `patch`/`none` so minor versions never drift from code.
- **Chart upgrades:** change `local.default_chart_versions` in `modules/platform-addons/locals.tf` and release a new tag. A customer can override one chart with `platform.chart_versions` in `config.yaml`.
- **KMS key rotation:** create a new key version in the KMS Key Vault and re-run the customer's pipeline. AKS re-encrypts secrets with the new version.
- **Delete lock:** set `features.delete_lock: false` and apply before removing node pools. To destroy the whole environment, set it together with `mode: destroy` (see [Create / destroy toggle](#create--destroy-toggle-mode)).
- **Node Auto Provisioning vs cluster-autoscaler:** they can't run together. With NAP on, the system pool and any `user_node_pools` have a fixed size. Set `features.node_auto_provisioning: false` to use cluster-autoscaler on `cluster.user_node_pools` instead.
