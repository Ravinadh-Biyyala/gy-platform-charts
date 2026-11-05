# Helm charts (NKP clusters)

Source of truth for the apps that run on the DEV (`ksquare-cluster-workload`) and UAT (`uat-workload`)
clusters outside Runtime Fabric. Charts were recovered from the Helm releases on the clusters
(`scripts/recover-chart.sh`) and verified: `helm template` of each chart + its env values
reproduces what is running.

## Charts

| Chart | Env | Namespace | Release |
|---|---|---|---|
| `charts/gdb` | DEV, UAT | gdb-los | gdb |
| `charts/keycloak` | UAT | keycloak | keycloak |
| `charts/gpl-customer-portal` | DEV | react-gpl-portal-dev | gpl-customer-portal |
| `charts/mayan` | DEV | mayan-edms | mayan |
| `charts/mayan-uat` | UAT | mayan-edms | mayan |
| `charts/mayan-node-backend` | DEV, UAT | mayan-edms | mayan-node-backend |
| `charts/embrace` | DEV | mhsss-embrace | embrace |
| `upstream/mariadb-operator` | DEV, UAT | values only (upstream chart 26.10.1) | |

`values.yaml` = chart defaults, `values-<env>.yaml` = what differs per environment.

## Secrets - never in git

Passwords are blank (`""`) in this repo. Real values are supplied at deploy time from a private
values file kept outside git, or the chart reads an existing Kubernetes Secret
(gdb, keycloak, gpl-customer-portal, mayan-node-backend: create the Secret first, see each chart).

```bash
# example: mayan on DEV
helm upgrade --install mayan charts/mayan -n mayan-edms \
  -f charts/mayan/values-dev.yaml -f <private>/mayan-dev-secrets.yaml
```

Always run `helm diff upgrade` (helm-diff plugin) or `helm template` + diff before an upgrade.

## Recover a chart from a running release

```bash
./scripts/recover-chart.sh <context> <namespace> <release> <output-dir>
```
Writes the chart plus `.recovered/` (installed values + rendered manifest; may contain secrets,
git-ignored).

## Known follow-ups
- mayan DEV and UAT are different charts (165 template lines apart) - merge into one later.
- embrace release shows `failed` (install on 2026-08-12 timed out) but the app runs; next upgrade fixes the status.
- Resources created before Helm (mps, nis, kodi, onecitizen, postgres, keycloak DEV, mule-log-archiver) still to be exported.
