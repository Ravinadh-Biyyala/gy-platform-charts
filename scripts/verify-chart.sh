#!/usr/bin/env bash
# Check that a chart + its env values reproduce what is running (read-only: kubectl diff changes nothing).
# Usage: ./scripts/verify-chart.sh <chart> <env> <context> <namespace> [release]
#   e.g. ./scripts/verify-chart.sh mps dev DEV react-mps-dev
# Empty diff = chart matches the cluster. PVCs will only show the added "helm.sh/resource-policy: keep" annotation.
set -uo pipefail
chart=$1 env=$2 ctx=$3 ns=$4 rel=${5:-$1}
d=$(dirname "$0")/../charts/$chart
helm lint "$d" -f "$d/values-$env.yaml" --quiet || exit 1
out=$(helm template "$rel" "$d" -n "$ns" -f "$d/values-$env.yaml") || exit 1
echo "== $chart/$env -> $ctx/$ns: $(grep -c '^kind:' <<<"$out") objects"
if kubectl --context "$ctx" -n "$ns" diff -f - <<<"$out"; then echo "NO DIFFERENCES"; else echo "(differences above)"; fi
