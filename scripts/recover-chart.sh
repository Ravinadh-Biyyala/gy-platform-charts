#!/usr/bin/env bash
# Rebuild a Helm chart's SOURCE (Chart.yaml, values.yaml, templates/...) from a release
# that is installed on the cluster. Helm keeps a full copy of the chart inside the
# release secret (sh.helm.release.v1.<release>.v<revision>), so charts that were
# installed "from someone's laptop" can be recovered without that laptop.
#
# Read-only: it only reads the release secret.
#
# Usage: ./recover-chart.sh <context> <namespace> <release> <output-dir>
#   e.g. ./recover-chart.sh DEV mayan-edms mayan-node-backend charts/mayan-node-backend
#
# Output:
#   <output-dir>/Chart.yaml            (as JSON - valid YAML)
#   <output-dir>/values.yaml           chart defaults (as JSON - valid YAML; comments are lost)
#   <output-dir>/templates/...         original templates, byte for byte
#   <output-dir>/<other files>         any extra chart files (README, files/...)
#   <output-dir>/.recovered/values-<context>.yaml   values the release was installed WITH (user-supplied)
#   <output-dir>/.recovered/manifest-<context>.yaml what the release rendered (for comparison)
set -euo pipefail
ctx=$1; ns=$2; rel=$3; out=$4
command -v jq >/dev/null || { echo "jq is required (sudo apt install -y jq)"; exit 1; }

# the currently deployed revision's secret (fall back to the highest revision number)
secret=$(kubectl --context "$ctx" -n "$ns" get secret -l "owner=helm,name=$rel,status=deployed" \
          -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -z "$secret" ]; then
  secret=$(kubectl --context "$ctx" -n "$ns" get secret -l "owner=helm,name=$rel" \
            -o jsonpath='{range .items[*]}{.metadata.labels.version}{" "}{.metadata.name}{"\n"}{end}' \
            | sort -n | tail -1 | cut -d' ' -f2)
fi
[ -n "$secret" ] || { echo "no helm release secret for $rel in $ns ($ctx)"; exit 1; }
echo "reading $secret"

json=$(kubectl --context "$ctx" -n "$ns" get secret "$secret" -o jsonpath='{.data.release}' \
        | base64 -d | base64 -d | gunzip -c)

mkdir -p "$out/templates" "$out/.recovered"
echo "$json" | jq '.chart.metadata' > "$out/Chart.yaml"
echo "$json" | jq '.chart.values // {}' > "$out/values.yaml"

# templates and other files: { name: "templates/x.yaml", data: <base64> }
for key in templates files; do
  echo "$json" | jq -r --arg k "$key" '.chart[$k] // [] | .[] | "\(.name)\t\(.data)"' |
  while IFS=$'\t' read -r name data; do
    mkdir -p "$out/$(dirname "$name")"
    echo "$data" | base64 -d > "$out/$name"
  done
done

echo "$json" | jq '.config // {}' > "$out/.recovered/values-$ctx.yaml"
echo "$json" | jq -r '.manifest'   > "$out/.recovered/manifest-$ctx.yaml"

echo "recovered chart $(echo "$json" | jq -r '.chart.metadata.name + " " + .chart.metadata.version') -> $out"
find "$out" -type f | sort
