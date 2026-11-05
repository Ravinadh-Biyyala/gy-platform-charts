{{/* The name every object carries, and the value of its `app` label. */}}
{{- define "mnb.name" -}}
{{- .Values.backend.deployment -}}
{{- end -}}

{{/* The ConfigMap the container reads with envFrom, like mayan-app reads
     mayan-config. */}}
{{- define "mnb.configMapName" -}}
{{- printf "%s-config" (include "mnb.name" .) -}}
{{- end -}}

{{/* The values file names the namespace; the release must be installed
     there (helm ... -n <namespace>). */}}
{{- define "mnb.checkNamespace" -}}
{{- if and .Values.namespace (ne .Values.namespace .Release.Namespace) -}}
{{- fail (printf "deploy/values says namespace %q, but the release namespace is %q: pass -n %s" .Values.namespace .Release.Namespace .Values.namespace) -}}
{{- end -}}
{{- end -}}
