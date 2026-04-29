{{- define "kafka.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kafka.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "kafka.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "kafka.labels" -}}
app.kubernetes.io/name: {{ include "kafka.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "kafka.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kafka.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "kafka.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride -}}
{{- end -}}

{{- define "kafka.clusterDomain" -}}
{{- default "cluster.local" .Values.clusterDomain -}}
{{- end -}}

{{- define "kafka.headlessServiceName" -}}
{{- default (printf "%s-headless" (include "kafka.fullname" .)) .Values.kafka.headlessService.nameOverride -}}
{{- end -}}

{{- define "kafka.serviceName" -}}
{{- default (include "kafka.fullname" .) .Values.kafka.service.nameOverride -}}
{{- end -}}

{{- define "kafka.kerberosSecretName" -}}
{{- default (printf "%s-kerberos" (include "kafka.fullname" .)) .Values.kerberos.existingSecret -}}
{{- end -}}

{{- define "kafka.controllerQuorum" -}}
{{- $fullname := include "kafka.fullname" . -}}
{{- $headless := include "kafka.headlessServiceName" . -}}
{{- $namespace := include "kafka.namespace" . -}}
{{- $domain := include "kafka.clusterDomain" . -}}
{{- $port := int .Values.kafka.ports.controller.containerPort -}}
{{- $items := list -}}
{{- range $i := until (int .Values.kafka.replicaCount) -}}
{{- $items = append $items (printf "%d@%s-%d.%s.%s.svc.%s:%d" (add1 $i) $fullname $i $headless $namespace $domain $port) -}}
{{- end -}}
{{- join "," $items -}}
{{- end -}}

{{- define "kafka.bootstrapServers" -}}
{{- $fullname := include "kafka.fullname" . -}}
{{- $headless := include "kafka.headlessServiceName" . -}}
{{- $namespace := include "kafka.namespace" . -}}
{{- $domain := include "kafka.clusterDomain" . -}}
{{- $port := int .Values.kafka.ports.client.containerPort -}}
{{- $items := list -}}
{{- range $i := until (int .Values.kafka.replicaCount) -}}
{{- $items = append $items (printf "%s-%d.%s.%s.svc.%s:%d" $fullname $i $headless $namespace $domain $port) -}}
{{- end -}}
{{- join "," $items -}}
{{- end -}}

{{- define "kafka.bootstrapServersWithProtocol" -}}
{{- $protocol := .Values.kafka.interBrokerListenerName -}}
{{- $items := list -}}
{{- range $server := splitList "," (include "kafka.bootstrapServers" .) -}}
{{- $items = append $items (printf "%s://%s" $protocol $server) -}}
{{- end -}}
{{- join "," $items -}}
{{- end -}}

{{- define "kafka.kdcExtraServicePrincipals" -}}
{{- $fullname := include "kafka.fullname" . -}}
{{- $headless := include "kafka.headlessServiceName" . -}}
{{- $namespace := include "kafka.namespace" . -}}
{{- $domain := include "kafka.clusterDomain" . -}}
{{- $realm := .Values.kerberos.realm -}}
{{- $items := list -}}
{{- if .Values.kerberos.generateKafkaPrincipals -}}
{{- range $i := until (int .Values.kafka.replicaCount) -}}
{{- $fqdn := printf "%s-%d.%s.%s.svc.%s" $fullname $i $headless $namespace $domain -}}
{{- $items = append $items (printf "kafka/%s@%s:%s/kafka-%d.keytab" $fqdn $realm $.Values.kerberos.keytabsDir $i) -}}
{{- end -}}
{{- end -}}
{{- range .Values.kerberos.extraServicePrincipals -}}
{{- $items = append $items (printf "%s:%s" .principal .keytab) -}}
{{- end -}}
{{- join "," $items -}}
{{- end -}}
