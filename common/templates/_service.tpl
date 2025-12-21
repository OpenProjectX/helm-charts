{{- define "common.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type | default "ClusterIP" }}
  selector:
    app.kubernetes.io/name: {{ include "common.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
  ports:
    {{- toYaml .Values.service.ports | nindent 4 }}
{{- end }}
