# Azure AKS Production-Grade Terraform Reference

This repository contains a production-focused Azure Kubernetes Service (AKS) Terraform implementation designed as a secure, modular baseline for deploying a managed Kubernetes cluster in Azure.

## What this model includes

- Resource group and networking
- Azure VNet + subnet with NSG
- AKS cluster with RBAC enabled
- System and user node pools
- Azure Monitor / Log Analytics integration
- Private-cluster option
- OIDC / workload identity support
- Diagnostic settings and secure defaults
- Example variables and outputs

## Directory structure

```text
.
├── README.md
├── .gitignore
├── versions.tf
├── main.tf
├── variables.tf
├── locals.tf
├── outputs.tf
├── terraform.tfvars.example
├── modules
│   ├── network
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── monitoring
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── aks
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── docs
    └── architecture.md
```

## Requirements

- Terraform >= 1.7.0
- Azure subscription with permission to create resource groups, networking, AKS, Log Analytics, and identity resources
- Azure CLI authenticated (`az login`)
- SSH public key for Linux node access

## Quick start

1. Clone the repo.
2. Copy the example variables:

```bash
cp terraform.tfvars.example terraform.tfvars
```

3. Update `terraform.tfvars` with your values.
4. Initialize and validate:

```bash
terraform init
terraform validate
```

5. Review the plan:

```bash
terraform plan
```

6. Apply:

```bash
terraform apply
```

## Recommended production settings

- Use a dedicated resource group for the cluster.
- Restrict API server access with `authorized_ip_ranges` or enable private cluster mode.
- Keep AKS and Kubernetes versions current.
- Separate system and workload node pools.
- Enable Azure Monitor and diagnostic logs.
- Use managed identity and OIDC-based workload identity for workloads.

## Important notes

- `terraform.tfvars` is intentionally not committed and should contain secrets and environment-specific settings.
- SSH keys should be generated and handled securely.
- For private cluster deployments, ensure you have network connectivity to the private API endpoint.

## Example deployment flow

```bash
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars" -auto-approve
```

## Outputs

After deployment, the root module exposes:

- Resource group name
- AKS cluster ID
- Cluster name
- Kubeconfig (sensitive)
- FQDN
- Log Analytics workspace ID
- OIDC issuer URL

## License

This repository is provided as an infrastructure reference and can be adapted for your organization’s standards.

