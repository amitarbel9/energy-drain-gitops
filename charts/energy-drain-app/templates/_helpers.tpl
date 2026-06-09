{{/* helper templates for consistent naming and standard labels */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "energy-drain.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "energy-drain.fullname" -}}
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
{{- define "energy-drain.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels used across resources.
*/}}
{{- define "energy-drain.labels" -}}
helm.sh/chart: {{ include "energy-drain.chart" . }}
{{ include "energy-drain.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels used for Deployment and Service matching.
*/}}
{{- define "energy-drain.selectorLabels" -}}
app.kubernetes.io/name: {{ include "energy-drain.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
