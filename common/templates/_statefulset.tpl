{{- define "common.statefulset" -}}
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}

spec:
  serviceName: {{ include "common.fullname" . }}-headless
  replicas: {{ .Values.replicaCount | default 1 }}

  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "common.name" . }}
      app.kubernetes.io/instance: {{ .Release.Name }}

  template:
    metadata:
      labels:
        {{- include "common.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      annotations:
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}

    spec:
      {{- with .Values.serviceAccountName }}
      serviceAccountName: {{ . }}
      {{- end }}

      {{- with .Values.securityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}

      {{- with .Values.initContainers }}
      initContainers:
        {{- toYaml . | nindent 8 }}
      {{- end }}

      containers:
        - name: {{ include "common.name" . }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}

          {{- with .Values.containerSecurityContext }}
          securityContext:
            {{- toYaml . | nindent 12 }}
          {{- end }}

          {{- with .Values.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}

          {{- with .Values.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}

          {{- with .Values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}

          volumeMounts:
            {{- if .Values.persistence.enabled }}
            # --- per-replica data ---
            - name: data
              mountPath: {{ .Values.persistence.mount.mountPath }}
            {{- end }}

            # --- secret mounts ---
            {{- range .Values.secretMounts }}
            - name: {{ .name }}
              mountPath: {{ .mountPath }}
              readOnly: true
            {{- end }}

            # --- configmap mounts ---
            {{- range .Values.configMapMounts }}
            - name: {{ .name }}
              mountPath: {{ .mountPath }}
              readOnly: true
            {{- end }}

            # --- escape hatch ---
            {{- with .Values.volumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}

      volumes:
        # --- secret volumes ---
        {{- range .Values.secretMounts }}
        - name: {{ .name }}
          secret:
            secretName: {{ .secretName }}
        {{- end }}

        # --- configmap volumes ---
        {{- range .Values.configMapMounts }}
        - name: {{ .name }}
          configMap:
            name: {{ .configMapName }}
        {{- end }}

        # --- escape hatch ---
        {{- with .Values.volumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}

  {{- if .Values.persistence.enabled }}
  volumeClaimTemplates:
    - metadata:
        name: data
        labels:
          {{- include "common.labels" . | nindent 10 }}
      spec:
        accessModes:
          {{- toYaml .Values.persistence.pvc.accessModes | nindent 10 }}
        resources:
          requests:
            storage: {{ .Values.persistence.pvc.size }}
        {{- with .Values.persistence.pvc.storageClassName }}
        storageClassName: {{ . }}
        {{- end }}
  {{- end }}
{{- end }}
