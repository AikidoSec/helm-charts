{{/*
Expand the name of the chart.
*/}}
{{- define "kubernetes-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kubernetes-agent.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kubernetes-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kubernetes-agent.labels" -}}
helm.sh/chart: {{ include "kubernetes-agent.chart" . }}
{{ include "kubernetes-agent.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Values.agent.image.tag | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kubernetes-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubernetes-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kubernetes-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kubernetes-agent.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Calculate GOMEMLIMIT value based on memory limit
Set Go memory limit to 90% of container memory limit (min 100 MiB)
1. Convert memory limit to MiB (Gi -> MiB * 1024, Mi -> MiB * 1)
2. Calculate 90% with 100 MiB minimum
3. Use GiB if result >= 1024 MiB, otherwise use MiB
*/}}
{{- define "kubernetes-agent.goMemLimit" -}}
{{- $memMiB := 0 -}}
{{- if contains "Gi" .Values.agent.resources.limits.memory -}}
  {{- $memMiB = mul (.Values.agent.resources.limits.memory | replace "Gi" "" | int) 1024 -}}
{{- else -}}
  {{- $memMiB = (.Values.agent.resources.limits.memory | replace "Mi" "" | int) -}}
{{- end -}}
{{- $goMemLimit := max 100 (mul (div $memMiB 10) 9) -}}
{{- $goMemLimit }}MiB
{{- end -}}

{{- define "kubernetes-sbom-collector.goMemLimit" -}}
{{- $memMiB := 0 -}}
{{- if contains "Gi" .Values.sbomCollector.resources.limits.memory -}}
  {{- $memMiB = mul (.Values.sbomCollector.resources.limits.memory | replace "Gi" "" | int) 1024 -}}
{{- else -}}
  {{- $memMiB = (.Values.sbomCollector.resources.limits.memory | replace "Mi" "" | int) -}}
{{- end -}}
{{- $goMemLimit := max 100 (mul (div $memMiB 10) 9) -}}
{{- $goMemLimit }}MiB
{{- end -}}

{{/*
Get the secret name to use for the agent configuration.
Uses externalSecret if provided, otherwise uses the chart name.
*/}}
{{- define "kubernetes-agent.secretName" -}}
{{- if .Values.agent.externalSecret -}}
{{- .Values.agent.externalSecret -}}
{{- else -}}
{{- include "kubernetes-agent.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
Calculate startup probe failure threshold based on controllerCacheSyncTimeout
Parse timeout value (e.g., "30m", "1h", "300s") and convert to failure threshold
with 10-second period checks.
*/}}
{{- define "kubernetes-agent.startupProbeFailureThreshold" -}}
{{- $timeout := .Values.agent.controllerCacheSyncTimeout -}}
{{- $seconds := 0 -}}
{{- if hasSuffix "s" $timeout -}}
  {{- $seconds = ($timeout | replace "s" "" | int) -}}
{{- else if hasSuffix "m" $timeout -}}
  {{- $seconds = mul ($timeout | replace "m" "" | int) 60 -}}
{{- else if hasSuffix "h" $timeout -}}
  {{- $seconds = mul ($timeout | replace "h" "" | int) 3600 -}}
{{- else -}}
  {{- $seconds = 300 -}}
{{- end -}}
{{- $failureThreshold := div $seconds 10 -}}
{{- max 30 $failureThreshold -}}
{{- end -}}

{{- define "sbom-collector.name" -}}
{{- printf "%s-sbom-collector" (include "kubernetes-agent.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
