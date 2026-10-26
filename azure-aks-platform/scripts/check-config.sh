#!/usr/bin/env bash
# Checks a customer config against the hub rules (modules/config) and prints its mode: create or destroy.
#
#   scripts/check-config.sh <path/to/environments/<env>/config.yaml>
#
# Needs no Azure access. Typos, missing keys, and a destroy while features.delete_lock is on fail here,
# before any stack is planned.
set -euo pipefail

[ $# -eq 1 ] || { sed -n '2,7p' "$0" >&2; exit 2; }
[ -f "$1" ] || { echo "config not found: $1" >&2; exit 2; }

config=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
module=$(cd "$(dirname "$0")/.." && pwd)/modules/config
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The module has no resources, so apply only evaluates its outputs and their preconditions.
# State goes to a throwaway file so nothing is written next to the module.
terraform -chdir="$module" init -input=false >&2
terraform -chdir="$module" apply -input=false -auto-approve -state="$tmp/config.tfstate" -var "config_file=$config" >&2
terraform -chdir="$module" output -state="$tmp/config.tfstate" -raw mode
