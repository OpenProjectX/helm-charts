{{- define "common.httproute" -}}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "common.fullname" . }}
spec:
  parentRefs:
    {{- toYaml .Values.httpRoute.parentRefs | nindent 4 }}
  hostnames:
    {{- toYaml .Values.httpRoute.hostnames | nindent 4 }}
  rules:
    {{- toYaml .Values.httpRoute.rules | nindent 4 }}
{{- end }}
