{{/*
Helpers. Every component helper takes a dict:
  component: api | web | predicciones | ingesta | postgres
  ctx:       the root context ($)
  version:   image tag (only for the version label)
*/}}

{{- define "statline.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Object name for a component: <release>-<component>. */}}
{{- define "statline.fullname" -}}
{{- printf "%s-%s" .ctx.Release.Name .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels. Only app.kubernetes.io/name is used for selectors (AGENTS.md section 7),
so the name carries the component: statline-api, statline-web, ...
*/}}
{{- define "statline.selectorLabels" -}}
app.kubernetes.io/name: {{ printf "statline-%s" .component | quote }}
{{- end -}}

{{- define "statline.labels" -}}
{{ include "statline.selectorLabels" . }}
app.kubernetes.io/instance: {{ .ctx.Release.Name | quote }}
app.kubernetes.io/part-of: statline
app.kubernetes.io/component: {{ .component | quote }}
app.kubernetes.io/version: {{ .version | default "unknown" | toString | quote }}
app.kubernetes.io/managed-by: {{ .ctx.Release.Service | quote }}
helm.sh/chart: {{ printf "%s-%s" .ctx.Chart.Name .ctx.Chart.Version | replace "+" "_" | quote }}
statline.io/environment: {{ .ctx.Values.environment | quote }}
{{- end -}}

{{/* Image reference: <global.imageRegistry>/<repository>:<tag>. The tag is required. */}}
{{- define "statline.image" -}}
{{- $tag := required (printf "%s.image.tag is required: set it in the values file" .component) .image.tag | toString -}}
{{- if .ctx.Values.global.imageRegistry -}}
{{- printf "%s/%s:%s" .ctx.Values.global.imageRegistry .image.repository $tag -}}
{{- else -}}
{{- printf "%s:%s" .image.repository $tag -}}
{{- end -}}
{{- end -}}

{{/* Redis URL built from the redis.* values. */}}
{{- define "statline.redisUrl" -}}
{{- printf "redis://%s:%v/%v" .Values.redis.host .Values.redis.port .Values.redis.dbIndex -}}
{{- end -}}

{{/* Pod-level security context (non-root, seccomp). */}}
{{- define "statline.podSecurity" -}}
runAsNonRoot: true
runAsUser: {{ .uid }}
runAsGroup: {{ .uid }}
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{/* Container-level security context. */}}
{{- define "statline.containerSecurity" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end -}}

{{/*
Env entries that read the given keys from the statline Secret.
Input: dict with keys (list of env var names) and secretName.
*/}}
{{- define "statline.secretEnv" -}}
{{- range .keys }}
- name: {{ . }}
  valueFrom:
    secretKeyRef:
      name: {{ $.secretName }}
      key: {{ . }}
{{- end }}
{{- end -}}

{{/* Volume for the Secrets Store CSI driver (csi mode only). Read-only at /mnt/secrets-store. */}}
{{- define "statline.secretVolume" -}}
{{- if eq .Values.secrets.mode "csi" }}
- name: secrets-store
  csi:
    driver: secrets-store.csi.k8s.io
    readOnly: true
    volumeAttributes:
      secretProviderClass: {{ .Values.secrets.csi.secretProviderClassName | quote }}
{{- end }}
{{- end -}}

{{- define "statline.secretVolumeMount" -}}
{{- if eq .Values.secrets.mode "csi" }}
- name: secrets-store
  mountPath: /mnt/secrets-store
  readOnly: true
{{- end }}
{{- end -}}

{{/* Writable scratch space for read-only root filesystems. */}}
{{- define "statline.tmpVolume" -}}
- name: tmp
  emptyDir: {}
{{- end -}}

{{- define "statline.tmpVolumeMount" -}}
- name: tmp
  mountPath: /tmp
{{- end -}}

{{/*
Plain-mode Secret data: secrets.plain.data, with DATABASE_URL pointing to the dev Postgres
when devPostgres.enabled (k3d only). Rendered as stringData lines.
*/}}
{{- define "statline.secretData" -}}
{{- $data := deepCopy .Values.secrets.plain.data -}}
{{- if .Values.devPostgres.enabled -}}
{{- $_ := set $data "DATABASE_URL" (printf "postgresql://%s:%s@%s:5432/%s" .Values.devPostgres.user .Values.devPostgres.password (include "statline.fullname" (dict "component" "postgres" "ctx" .)) .Values.devPostgres.database) -}}
{{- end -}}
{{- range $k, $v := $data }}
{{ $k }}: {{ $v | toString | quote }}
{{- end -}}
{{- end -}}
