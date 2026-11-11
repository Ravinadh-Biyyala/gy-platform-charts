# kodi DEV Helm chart

Export-derived templates for `kodi-dev`. **Not yet adopted by Helm**.

Render without changing the cluster:

```bash
helm lint charts/kodi -f charts/kodi/values-dev.yaml
helm template kodi charts/kodi -f charts/kodi/values-dev.yaml > /tmp/kodi-rendered.yaml
```

## Deployment safeguards
- Do not run `helm install` or `helm upgrade` against existing unmanaged resources without an ownership/adoption plan.
- Existing Kubernetes Secrets must already exist; Secret data is not included.
- Review `REVIEW_AND_SET` ConfigMap placeholders and all other exported settings before deployment.
- StatefulSet volume claim templates and storage require special review before any Helm adoption.
- This chart is a snapshot, not a verified disaster recovery solution.
