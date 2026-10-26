#!/usr/bin/env bash
# Runs one hub stack against one customer environment config.
#
#   scripts/run-stack.sh <01-cluster|02-platform> <plan|apply|plan-destroy|destroy> <path/to/environments/<env>/config.yaml>
#
# Required env:
#   TF_STATE_RESOURCE_GROUP   resource group of the customer's state storage account
#   TF_STATE_STORAGE_ACCOUNT  state storage account
#   TF_STATE_KEY_PREFIX       blob prefix for this environment, e.g. my-org/azure-aks-customer/prod
# Optional env:
#   TF_STATE_CONTAINER        default: tfstate
#   TF_PLAN_CHANGES_FILE      if set, the stage name is appended to this file when its plan has changes
#   TF_VAR_kubelogin_login_mode, TF_VAR_kubelogin_extra_args (02-platform)
set -euo pipefail

usage() { sed -n '2,14p' "$0" >&2; exit 2; }
[ $# -eq 3 ] || usage

stage=$1
action=$2
case "$stage" in 01-cluster | 02-platform) ;; *) usage ;; esac
case "$action" in plan | apply | plan-destroy | destroy) ;; *) usage ;; esac
[ -f "$3" ] || { echo "config not found: $3" >&2; exit 2; }

config=$(cd "$(dirname "$3")" && pwd)/$(basename "$3")
root=$(cd "$(dirname "$0")/.." && pwd)
: "${TF_STATE_RESOURCE_GROUP:?}" "${TF_STATE_STORAGE_ACCOUNT:?}" "${TF_STATE_KEY_PREFIX:?}"

destroy_flag=""
case "$action" in *destroy) destroy_flag="-destroy" ;; esac

notice() { if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::notice::$*"; else echo "$*"; fi; }

init() {
  terraform -chdir="$root/stacks/$1" init -input=false -reconfigure \
    -backend-config="resource_group_name=$TF_STATE_RESOURCE_GROUP" \
    -backend-config="storage_account_name=$TF_STATE_STORAGE_ACCOUNT" \
    -backend-config="container_name=${TF_STATE_CONTAINER:-tfstate}" \
    -backend-config="key=$TF_STATE_KEY_PREFIX/$1.tfstate"
}

# 02-platform reads the live cluster at plan time. On a brand-new environment the cluster
# does not exist until 01-cluster is applied, so a plan-only run skips stage 2. After a destroy
# (or one that stopped after 01-cluster) there is no cluster left, so there is nothing to remove in stage 2.
if [ "$stage" = 02-platform ]; then
  init 01-cluster >/dev/null
  if ! terraform -chdir="$root/stacks/01-cluster" output -raw cluster_name >/dev/null 2>&1; then
    if [ -n "$destroy_flag" ]; then
      notice "Cluster does not exist; nothing to destroy in 02-platform."
    else
      notice "Cluster not created yet; skipping 02-platform $action. It runs after 01-cluster is applied."
    fi
    exit 0
  fi
fi

init "$stage"
rc=0
# shellcheck disable=SC2086 # destroy_flag is empty or a single flag
terraform -chdir="$root/stacks/$stage" plan -input=false $destroy_flag -detailed-exitcode \
  -var "config_file=$config" -out=tfplan || rc=$?
case $rc in
  0) ;;
  2) [ -z "${TF_PLAN_CHANGES_FILE:-}" ] || echo "$stage" >>"$TF_PLAN_CHANGES_FILE" ;;
  *) exit "$rc" ;;
esac

if [ "$action" = apply ] || [ "$action" = destroy ]; then
  terraform -chdir="$root/stacks/$stage" apply -input=false tfplan
fi
