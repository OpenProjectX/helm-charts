{{- define "common.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end }}

{{- define "common.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "common.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "common.labels" -}}
app.kubernetes.io/name: {{ include "common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: Helm
{{- end }}

