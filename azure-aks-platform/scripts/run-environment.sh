#!/usr/bin/env bash
# Runs both stacks for one customer environment, in the order that the config's `mode` needs.
#
#   scripts/run-environment.sh <plan|apply> <path/to/environments/<env>/config.yaml>
#
#   mode: create    01-cluster, then 02-platform (plan, or plan + apply)
#   mode: destroy   destroy 02-platform, then 01-cluster (destroy plan, or destroy plan + apply)
#
# Same env as scripts/run-stack.sh. Optional:
#   EXPECTED_MODE   create or destroy; fail if config.yaml says otherwise, so an approval for one mode can't run the other
set -euo pipefail

usage() { sed -n '2,10p' "$0" >&2; exit 2; }
[ $# -eq 2 ] || usage
case "$1" in plan | apply) ;; *) usage ;; esac

action=$1
config=$2
scripts=$(cd "$(dirname "$0")" && pwd)

mode=$(bash "$scripts/check-config.sh" "$config")
echo "mode: $mode"
if [ -n "${EXPECTED_MODE:-}" ] && [ "$mode" != "$EXPECTED_MODE" ]; then
  echo "config.yaml has mode: $mode, but this run was approved for mode: $EXPECTED_MODE. Re-run the pipeline." >&2
  exit 1
fi

if [ "$mode" = create ]; then
  bash "$scripts/run-stack.sh" 01-cluster "$action" "$config"
  bash "$scripts/run-stack.sh" 02-platform "$action" "$config"
else
  [ "$action" = plan ] && stack_action=plan-destroy || stack_action=destroy
  # Kubernetes resources go first, while the cluster they live in still exists
  bash "$scripts/run-stack.sh" 02-platform "$stack_action" "$config"
  bash "$scripts/run-stack.sh" 01-cluster "$stack_action" "$config"
fi
