{{/* helper templates for consistent naming and standard labels */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "lingua-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "lingua-app.fullname" -}}
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
Create chart name and version as used by labels.
*/}}
{{- define "lingua-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels used across resources.
*/}}
{{- define "lingua-app.labels" -}}
helm.sh/chart: {{ include "lingua-app.chart" . }}
{{ include "lingua-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels used for Deployment and Service matching.
*/}}
{{- define "lingua-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lingua-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
