{{- define "common.pvc.single" -}}
{{- if and .Values.persistence.enabled .Values.persistence.pvc }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ default (include "common.fullname" .) .Values.persistence.pvc.name }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
    {{- with .Values.persistence.pvc.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- with .Values.persistence.pvc.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  accessModes:
    {{- toYaml .Values.persistence.pvc.accessModes | nindent 4 }}
  resources:
    requests:
      storage: {{ .Values.persistence.pvc.size }}
  volumeMode: {{ .Values.persistence.pvc.volumeMode | default "Filesystem" }}
  {{- with .Values.persistence.pvc.storageClassName }}
  storageClassName: {{ . }}
  {{- end }}

---

{{- end }}
{{- end }}



{{- define "common.pvc.multi" -}}
{{- range .Values.persistentVolumes }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ $.Release.Name }}-{{ .name }}
  labels:
    {{- include "common.labels" $ | nindent 4 }}
spec:
  accessModes:
    {{- toYaml .accessModes | nindent 4 }}
  resources:
    requests:
      storage: {{ .size }}
  {{- with .storageClassName }}
  storageClassName: {{ . }}
  {{- end }}
---
{{- end }}
{{- end }}
