{{- define "kafka-network.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kafka-network.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "kafka-network.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "kafka-network.labels" -}}
app.kubernetes.io/name: {{ include "kafka-network.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "kafka-network.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride -}}
{{- end -}}

{{- define "kafka-network.kafkaName" -}}
{{- default .Values.kafka.chartName .Values.kafka.nameOverride -}}
{{- end -}}

{{- define "kafka-network.kafkaFullname" -}}
{{- if .Values.kafka.fullnameOverride -}}
{{- .Values.kafka.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Values.kafka.releaseName .Values.kafka.chartName | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "kafka-network.kafkaClusterFullname" -}}
{{- $root := .root -}}
{{- $cluster := .cluster -}}
{{- if $cluster.name -}}
{{- printf "%s-%s" (include "kafka-network.kafkaFullname" $root) $cluster.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "kafka-network.kafkaFullname" $root -}}
{{- end -}}
{{- end -}}

{{- define "kafka-network.kafkaClusterLabel" -}}
{{- default "default" .cluster.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kafka-network.kafkaServiceName" -}}
{{- $fullname := include "kafka-network.kafkaFullname" . -}}
{{- $component := .component -}}
{{- if eq $component "ui" -}}
{{- printf "%s-ui" $fullname | trunc 63 | trimSuffix "-" -}}
{{- else if eq $component "schemaRegistry" -}}
{{- printf "%s-schema-registry" $fullname | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $fullname -}}
{{- end -}}
{{- end -}}
