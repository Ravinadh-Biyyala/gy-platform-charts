#!/usr/bin/env bash
# Export the live resources of a namespace that is NOT managed by Helm as clean YAML
# (one file per object), ready to become chart templates.
#
# Read-only. Secret VALUES are never written: only secret names + key names (_secrets.txt).
#
# Usage: ./scripts/export-namespace.sh <context> <namespace> <output-dir>
#   e.g. ./scripts/export-namespace.sh DEV react-mps-dev exports/DEV/react-mps-dev
#
# Skips: Helm-managed objects, objects owned by another object (pods, replicasets, endpoints,
# jobs created by cronjobs), kube-root-ca.crt, the default ServiceAccount.
# Strips: status, uid, resourceVersion, timestamps, managedFields, last-applied annotation,
# deployment revision, restartedAt, cluster IPs, PVC volume binding, namespace.
set -euo pipefail
ctx=$1; ns=$2; out=$3
command -v jq >/dev/null || { echo "jq is required"; exit 1; }
command -v yq >/dev/null || { echo "yq is required (see step 6b)"; exit 1; }

KINDS="deployments statefulsets daemonsets cronjobs jobs services ingresses configmaps
persistentvolumeclaims serviceaccounts roles rolebindings networkpolicies
horizontalpodautoscalers poddisruptionbudgets middlewares.traefik.io ingressroutes.traefik.io"

CLEAN='
  select((.metadata.ownerReferences // []) | length == 0)
| select((.metadata.labels["app.kubernetes.io/managed-by"] // "") != "Helm")
| select(.metadata.name != "kube-root-ca.crt" and .metadata.name != "istio-ca-root-cert")
| select(.kind != "ServiceAccount" or .metadata.name != "default")
| del(.status, .metadata.namespace, .metadata.uid, .metadata.resourceVersion,
      .metadata.creationTimestamp, .metadata.generation, .metadata.managedFields,
      .metadata.selfLink)
| if .metadata.annotations then
    .metadata.annotations |= with_entries(select(.key | test(
      "^(kubectl.kubernetes.io/last-applied-configuration|deployment.kubernetes.io/revision|pv.kubernetes.io/.*|volume.beta.kubernetes.io/.*|volume.kubernetes.io/.*|control-plane.alpha.kubernetes.io/.*|field.cattle.io/.*)$") | not))
  else . end
| if .metadata.annotations == {} then del(.metadata.annotations) else . end
| if .spec.template.metadata then
    del(.spec.template.metadata.creationTimestamp)
    | if .spec.template.metadata.annotations then
        .spec.template.metadata.annotations |= del(.["kubectl.kubernetes.io/restartedAt"])
        | if .spec.template.metadata.annotations == {} then del(.spec.template.metadata.annotations) else . end
      else . end
  else . end
| if .kind == "Service" then del(.spec.clusterIP, .spec.clusterIPs) else . end
| if .kind == "PersistentVolumeClaim" then del(.spec.volumeName) else . end
| if .kind == "Job" then del(.spec.selector, .spec.template.metadata.labels["controller-uid"],
      .spec.template.metadata.labels["batch.kubernetes.io/controller-uid"],
      .spec.template.metadata.labels["batch.kubernetes.io/job-name"],
      .spec.template.metadata.labels["job-name"],
      .metadata.labels["controller-uid"], .metadata.labels["batch.kubernetes.io/controller-uid"],
      .metadata.labels["batch.kubernetes.io/job-name"], .metadata.labels["job-name"]) else . end
'

mkdir -p "$out"
count=0
for k in $KINDS; do
  json=$(kubectl --context "$ctx" -n "$ns" get "$k" -o json 2>/dev/null) || continue
  while IFS= read -r obj; do
    [ -n "$obj" ] || continue
    kind=$(jq -r '.kind' <<<"$obj" | tr '[:upper:]' '[:lower:]')
    name=$(jq -r '.metadata.name' <<<"$obj")
    yq -p=json -o=yaml -P '.' <<<"$obj" > "$out/$kind-$name.yaml"
    count=$((count + 1))
  done < <(jq -c ".items[] | $CLEAN" <<<"$json")
done

# Secrets: names, types and key names only - never values
kubectl --context "$ctx" -n "$ns" get secret -o json \
  | jq -r '.items[]
      | select(.type != "kubernetes.io/service-account-token" and .type != "helm.sh/release.v1")
      | "\(.metadata.name)  (\(.type))  keys: \((.data // {}) | keys | join(", "))"' > "$out/_secrets.txt"

echo "$ctx/$ns: $count objects -> $out   ($(wc -l < "$out/_secrets.txt") secrets listed by name)"
