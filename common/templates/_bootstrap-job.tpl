{{/*
Generic bootstrap Job template.

Usage:
{{ include "common.bootstrapJob" (dict
    "root" .
    "name" "bootstrap"
    "spec" .Values.bootstrap.job
) }}
*/}}

{{- define "common.bootstrapJob" -}}
{{- $root := .root -}}
{{- $name := .name | default "bootstrap" -}}
{{- $spec := .spec -}}

{{- if $spec.enabled }}

apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "common.fullname" $root }}-{{ $name }}
  labels:
    {{- include "common.labels" $root | nindent 4 }}
  annotations:
    helm.sh/hook: {{ $spec.hook | default "post-install" }}
    helm.sh/hook-weight: "{{ $spec.weight | default 10 }}"
{{/*    helm.sh/hook-delete-policy: {{ $spec.deletePolicy | default "hook-succeeded" }}*/}}
spec:
  backoffLimit: {{ $spec.backoffLimit | default 3 }}
  {{- if $spec.ttlSecondsAfterFinished }}
  ttlSecondsAfterFinished: {{ $spec.ttlSecondsAfterFinished }}
  {{- end }}
  template:
    spec:
      restartPolicy: Never
      {{- with $spec.serviceAccountName }}
      serviceAccountName: {{ . }}
      {{- end }}

      containers:
        - name: {{ $name }}
          image: {{ $spec.image }}
          imagePullPolicy: {{ $spec.imagePullPolicy | default "IfNotPresent" }}

          {{- with $spec.command }}
          command:
            {{- toYaml . | nindent 12 }}
          {{- end }}

          {{- with $spec.args }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}

          {{- with $spec.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}

          {{- with $spec.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}

          {{- with $spec.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}

      {{- with $spec.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}

{{- end }}
{{- end }}
