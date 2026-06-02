{{- define "fusion-electronics.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "fusion-electronics.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "fusion-electronics.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride -}}
{{- end -}}

{{- define "fusion-electronics.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "fusion-electronics.labels" -}}
helm.sh/chart: {{ include "fusion-electronics.chart" . }}
app.kubernetes.io/name: {{ include "fusion-electronics.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "fusion-electronics.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fusion-electronics.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "fusion-electronics.frontendName" -}}
{{- printf "%s-frontend" (include "fusion-electronics.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "fusion-electronics.backendName" -}}
{{- printf "%s-backend" (include "fusion-electronics.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "fusion-electronics.configName" -}}
{{- printf "%s-config" (include "fusion-electronics.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "fusion-electronics.secretName" -}}
{{- printf "%s-secrets" (include "fusion-electronics.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "fusion-electronics.mongodbName" -}}
{{- if .Values.mongodb.fullnameOverride -}}
{{- .Values.mongodb.fullnameOverride -}}
{{- else -}}
{{- printf "%s-mongodb" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "fusion-electronics.mongoUri" -}}
{{- $host := include "fusion-electronics.mongodbName" . -}}
{{- $port := .Values.mongodb.service.ports.mongodb | default 27017 -}}
{{- $db := .Values.mongodb.database | default "Ecommerce-Products" -}}
{{- if .Values.mongodb.auth.enabled -}}
{{- $user := .Values.mongodb.auth.username | default "fusion" -}}
{{- $pass := .Values.mongodb.auth.password | default "" -}}
{{- printf "mongodb://%s:%s@%s:%v/%s" $user $pass $host $port $db -}}
{{- else -}}
{{- printf "mongodb://%s:%v/%s" $host $port $db -}}
{{- end -}}
{{- end -}}

{{- define "fusion-electronics.observabilityNamespace" -}}
{{- default "logging" .Values.observability.namespace -}}
{{- end -}}

{{- define "fusion-electronics.fluentBitName" -}}
{{- printf "%s-fluent-bit" (include "fusion-electronics.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "fusion-electronics.teamsAlertName" -}}
{{- printf "%s-teams-alert" (include "fusion-electronics.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
