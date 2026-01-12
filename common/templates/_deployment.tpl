{{- define "common.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
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
        - name: {{ include "common.fullname" . }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}

          {{- with .Values.command }}
          command:
            {{- toYaml . | nindent 12 }}
          {{- end }}

          {{- with .Values.args }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}


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
            # --- single PVC ---
            {{- if and .Values.persistence.enabled .Values.persistence.mount }}
            - name: data
              mountPath: {{ .Values.persistence.mount.mountPath }}
              {{- with .Values.persistence.mount.subPath }}
              subPath: {{ . }}
              {{- end }}
            {{- end }}

            # --- multi PVC ---
            {{- range .Values.persistentVolumes }}
            - name: {{ .name }}
              mountPath: {{ .mountPath }}
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
            {{- end }}

            # --- raw user mounts ---
            {{- with .Values.volumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}


        {{- with .Values.sidecars }}
        {{- toYaml . | nindent 8 }}
        {{- end }}

        {{- with .Values.extraContainers }}
        {{- toYaml . | nindent 8 }}
        {{- end }}

      volumes:
        # --- single PVC ---
        {{- if .Values.persistence.enabled }}
        - name: data
          persistentVolumeClaim:
            claimName: {{ default (include "common.fullname" .) .Values.persistence.pvc.name }}
        {{- end }}

        # --- multi PVC ---
        {{- range .Values.persistentVolumes }}
        - name: {{ .name }}
          persistentVolumeClaim:
            claimName: {{ $.Release.Name }}-{{ .name }}
        {{- end }}

        # --- secret mounts (shortcut) ---
        {{- range .Values.secretMounts }}
        - name: {{ .name }}
          secret:
            secretName: {{ .secretName }}
        {{- end }}

        # --- configmap mounts (shortcut) ---
        {{- range .Values.configMapMounts }}
        - name: {{ .name }}
          configMap:
            name: {{ .configMapName }}
        {{- end }}

        # --- raw user volumes (escape hatch) ---
        {{- with .Values.volumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}

{{- end }}
