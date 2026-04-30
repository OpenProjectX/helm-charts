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

{{- define "kafka.effectiveClusters" -}}
{{- if .Values.kafka.clusters -}}
{{- toYaml .Values.kafka.clusters -}}
{{- else -}}
{{- toYaml (list (dict "name" "")) -}}
{{- end -}}
{{- end -}}

{{- define "kafka.cluster.fullname" -}}
{{- $root := .root -}}
{{- $cluster := .cluster -}}
{{- if $cluster.name -}}
{{- printf "%s-%s" (include "kafka.fullname" $root) $cluster.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "kafka.fullname" $root -}}
{{- end -}}
{{- end -}}

{{- define "kafka.cluster.label" -}}
{{- $cluster := .cluster -}}
{{- default "default" $cluster.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kafka.cluster.serviceName" -}}
{{- $root := .root -}}
{{- $cluster := .cluster -}}
{{- if and $cluster.service $cluster.service.nameOverride -}}
{{- $cluster.service.nameOverride -}}
{{- else if and (not $cluster.name) $root.Values.kafka.service.nameOverride -}}
{{- $root.Values.kafka.service.nameOverride -}}
{{- else -}}
{{- include "kafka.cluster.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "kafka.cluster.headlessServiceName" -}}
{{- $root := .root -}}
{{- $cluster := .cluster -}}
{{- if and $cluster.headlessService $cluster.headlessService.nameOverride -}}
{{- $cluster.headlessService.nameOverride -}}
{{- else if and (not $cluster.name) $root.Values.kafka.headlessService.nameOverride -}}
{{- $root.Values.kafka.headlessService.nameOverride -}}
{{- else -}}
{{- printf "%s-headless" (include "kafka.cluster.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "kafka.cluster.controllerQuorum" -}}
{{- $root := .root -}}
{{- $cluster := .cluster -}}
{{- $fullname := include "kafka.cluster.fullname" . -}}
{{- $headless := include "kafka.cluster.headlessServiceName" . -}}
{{- $namespace := include "kafka.namespace" $root -}}
{{- $domain := include "kafka.clusterDomain" $root -}}
{{- $port := int (default $root.Values.kafka.ports.controller.containerPort (dig "ports" "controller" "containerPort" nil $cluster)) -}}
{{- $replicas := int (default $root.Values.kafka.replicaCount $cluster.replicaCount) -}}
{{- $offset := int (default $root.Values.kafka.brokerIdOffset $cluster.brokerIdOffset) -}}
{{- $items := list -}}
{{- range $i := until $replicas -}}
{{- $items = append $items (printf "%d@%s-%d.%s.%s.svc.%s:%d" (add $i $offset) $fullname $i $headless $namespace $domain $port) -}}
{{- end -}}
{{- join "," $items -}}
{{- end -}}

{{- define "kafka.cluster.bootstrapServers" -}}
{{- $root := .root -}}
{{- $cluster := .cluster -}}
{{- $fullname := include "kafka.cluster.fullname" . -}}
{{- $headless := include "kafka.cluster.headlessServiceName" . -}}
{{- $namespace := include "kafka.namespace" $root -}}
{{- $domain := include "kafka.clusterDomain" $root -}}
{{- $port := int (default $root.Values.kafka.ports.client.containerPort (dig "ports" "client" "containerPort" nil $cluster)) -}}
{{- $replicas := int (default $root.Values.kafka.replicaCount $cluster.replicaCount) -}}
{{- $items := list -}}
{{- range $i := until $replicas -}}
{{- $items = append $items (printf "%s-%d.%s.%s.svc.%s:%d" $fullname $i $headless $namespace $domain $port) -}}
{{- end -}}
{{- join "," $items -}}
{{- end -}}

{{- define "kafka.cluster.bootstrapServersWithProtocol" -}}
{{- $root := .root -}}
{{- $cluster := .cluster -}}
{{- $protocol := default $root.Values.kafka.interBrokerListenerName $cluster.interBrokerListenerName -}}
{{- $items := list -}}
{{- range $server := splitList "," (include "kafka.cluster.bootstrapServers" .) -}}
{{- $items = append $items (printf "%s://%s" $protocol $server) -}}
{{- end -}}
{{- join "," $items -}}
{{- end -}}

{{- define "kafka.cluster.keytabPattern" -}}
{{- $root := .root -}}
{{- $cluster := .cluster -}}
{{- if and $cluster.kerberos $cluster.kerberos.keytabPattern -}}
{{- $cluster.kerberos.keytabPattern -}}
{{- else if $cluster.name -}}
{{- printf "%s/keytabs/kafka-%s-%%d.keytab" $root.Values.kerberos.mountPath $cluster.name -}}
{{- else -}}
{{- $root.Values.kafka.kerberos.keytabPattern -}}
{{- end -}}
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
{{- $cluster := first (include "kafka.effectiveClusters" . | fromYamlArray) -}}
{{- include "kafka.cluster.bootstrapServers" (dict "root" . "cluster" $cluster) -}}
{{- end -}}

{{- define "kafka.bootstrapServersWithProtocol" -}}
{{- $cluster := first (include "kafka.effectiveClusters" . | fromYamlArray) -}}
{{- include "kafka.cluster.bootstrapServersWithProtocol" (dict "root" . "cluster" $cluster) -}}
{{- end -}}

{{- define "kafka.kdcExtraServicePrincipals" -}}
{{- $root := . -}}
{{- $namespace := include "kafka.namespace" . -}}
{{- $domain := include "kafka.clusterDomain" . -}}
{{- $realm := .Values.kerberos.realm -}}
{{- $items := list -}}
{{- if .Values.kerberos.generateKafkaPrincipals -}}
{{- range $cluster := (include "kafka.effectiveClusters" . | fromYamlArray) -}}
{{- $fullname := include "kafka.cluster.fullname" (dict "root" $root "cluster" $cluster) -}}
{{- $headless := include "kafka.cluster.headlessServiceName" (dict "root" $root "cluster" $cluster) -}}
{{- $replicas := int (default $root.Values.kafka.replicaCount $cluster.replicaCount) -}}
{{- range $i := until $replicas -}}
{{- $fqdn := printf "%s-%d.%s.%s.svc.%s" $fullname $i $headless $namespace $domain -}}
{{- $keytabName := ternary (printf "kafka-%s-%d.keytab" $cluster.name $i) (printf "kafka-%d.keytab" $i) (ne (default "" $cluster.name) "") -}}
{{- $items = append $items (printf "kafka/%s@%s:%s/%s" $fqdn $realm $root.Values.kerberos.keytabsDir $keytabName) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- range .Values.kerberos.extraServicePrincipals -}}
{{- $items = append $items (printf "%s:%s" .principal .keytab) -}}
{{- end -}}
{{- join "," $items -}}
{{- end -}}
