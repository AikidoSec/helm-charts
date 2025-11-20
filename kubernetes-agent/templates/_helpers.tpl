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
Create the name of the service account to use for the agent
*/}}
{{- define "kubernetes-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kubernetes-agent.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Renders a value that contains template.
Usage:
{{ include "kubernetes-agent.renderTemplate" ( dict "value" .Values.path.to.the.Value "context" $) }}
*/}}
{{- define "kubernetes-agent.renderTemplate" -}}
    {{- if typeIs "string" .value }}
        {{- tpl .value .context }}
    {{- else }}
        {{- tpl (.value | toYaml) .context }}
    {{- end }}
{{- end -}}

{{/*
Create the name of the service account to use for the sbom collector
*/}}
{{- define "sbom-collector.serviceAccountName" -}}
{{- if .Values.sbomCollector.serviceAccount.create }}
{{- default (include "sbom-collector.name" .) .Values.sbomCollector.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.sbomCollector.serviceAccount.name }}
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

{{/*
SBOM Collector selector labels
*/}}
{{- define "sbom-collector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sbom-collector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: sbom-collector
{{- end }}

{{/*
SBOM Collector labels
*/}}
{{- define "sbom-collector.labels" -}}
helm.sh/chart: {{ include "kubernetes-agent.chart" . }}
{{ include "sbom-collector.selectorLabels" . }}
{{- if .Values.sbomCollector.image.tag }}
app.kubernetes.io/version: {{ .Values.sbomCollector.image.tag | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "threat-detection.name" -}}
{{- printf "%s-threat-detection" (include "kubernetes-agent.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "threat-detection.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubernetes-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: threat-detection
{{- end }}

{{/*
Threat detection labels
*/}}
{{- define "threat-detection.labels" -}}
helm.sh/chart: {{ include "kubernetes-agent.chart" . }}
{{ include "threat-detection.selectorLabels" . }}
{{- if .Values.threatdetection.image.tag }}
app.kubernetes.io/version: {{ .Values.threatdetection.image.tag | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "threat-detection.serviceAccountName" -}}
{{- if .Values.threatdetection.serviceAccount.create }}
{{- default (include "threat-detection.name" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.threatdetection.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the proper Falco image name
*/}}
{{- define "threat-detection.image" -}}
{{- with .Values.threatdetection.image.registry -}}
    {{- . }}/
{{- end -}}
{{- .Values.threatdetection.image.repository }}:
{{- .Values.threatdetection.image.tag -}}
{{- end -}}

{{/*
Return the proper Falco driver loader image name
*/}}
{{- define "threat-detection.driverLoader.image" -}}
{{- with .Values.threatdetection.driver.loader.initContainer.image.registry -}}
    {{- . }}/
{{- end -}}
{{- .Values.threatdetection.driver.loader.initContainer.image.repository }}:
{{- .Values.threatdetection.driver.loader.initContainer.image.tag | default .Chart.AppVersion -}}
{{- end -}}

{{/*
Return the proper Falcoctl image name
*/}}
{{- define "falcoctl.image" -}}
{{ printf "%s/%s:%s" .Values.threatdetection.falcoctl.image.registry .Values.threatdetection.falcoctl.image.repository .Values.threatdetection.falcoctl.image.tag }}
{{- end -}}

{{/*
Extract the unixSocket's directory path
*/}}
{{- define "threat-detection.unixSocketDir" -}}
{{- if and .Values.threatdetection.grpc.enabled .Values.threatdetection.grpc.bind_address (hasPrefix "unix://" .Values.threatdetection.grpc.bind_address) -}}
{{- .Values.threatdetection.grpc.bind_address | trimPrefix "unix://" | dir -}}
{{- end -}}
{{- end -}}

{{/*
Disable the syscall source if some conditions are met.
By default the syscall source is always enabled in threat-detection. If no syscall source is enabled, falco
exits. Here we check that no producers for syscalls event has been configured, and if true
we just disable the sycall source.
*/}}
{{- define "threat-detection.configSyscallSource" -}}
{{- $userspaceDisabled := true -}}
{{- $gvisorDisabled := (ne .Values.threatdetection.driver.kind  "gvisor") -}}
{{- $driverDisabled :=  (not .Values.threatdetection.driver.enabled) -}}
{{- if or (has "-u" .Values.threatdetection.extra.args) (has "--userspace" .Values.threatdetection.extra.args) -}}
{{- $userspaceDisabled = false -}}
{{- end -}}
{{- if and $driverDisabled $userspaceDisabled $gvisorDisabled }}
- --disable-source
- syscall
{{- end -}}
{{- end -}}

{{/*
We need the falco binary in order to generate the configuration for gVisor. This init container
is deployed within the Falco pod when gVisor is enabled. The image is the same as the one of Falco we are
deploying and the configuration logic is a bash script passed as argument on the fly. This solution should
be temporary and will stay here until we move this logic to the falcoctl tool.
*/}}
{{- define "threat-detection.gvisor.initContainer" -}}
- name: {{ .Chart.Name }}-gvisor-init
  image: {{ include "threat-detection.image" . }}
  imagePullPolicy: {{ .Values.threatdetection.image.pullPolicy }}
  args:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      root={{ .Values.threatdetection.driver.gvisor.runsc.root }}
      config={{ .Values.threatdetection.driver.gvisor.runsc.config }}

      echo "* Configuring Falco+gVisor integration...".
      # Check if gVisor is configured on the node.
      echo "* Checking for /host${config} file..."
      if [[ -f /host${config} ]]; then
          echo "* Generating the Falco configuration..."
          /usr/bin/falco --gvisor-generate-config=${root}/kubernetes-agent.sock > /host${root}/pod-init.json
          sed -E -i.orig '/"ignore_missing" : true,/d' /host${root}/pod-init.json
          if [[ -z $(grep pod-init-config /host${config}) ]]; then
            echo "* Updating the runsc config file /host${config}..."
            echo "  pod-init-config = \"${root}/pod-init.json\"" >> /host${config}
          fi
          # Endpoint inside the container is different from outside, add
          # "/host" to the endpoint path inside the container.
          echo "* Setting the updated Falco configuration to /gvisor-config/pod-init.json..."
          sed 's/"endpoint" : "\/run/"endpoint" : "\/host\/run/' /host${root}/pod-init.json > /gvisor-config/pod-init.json
      else
          echo "* File /host${config} not found."
          echo "* Please make sure that the gVisor is configured in the current node and/or the runsc root and config file path are correct"
          exit -1
      fi
      echo "* Falco+gVisor correctly configured."
      exit 0
  volumeMounts:
    - mountPath: /host{{ .Values.threatdetection.driver.gvisor.runsc.path }}
      name: runsc-path
      readOnly: true
    - mountPath: /host{{ .Values.threatdetection.driver.gvisor.runsc.root }}
      name: runsc-root
    - mountPath: /host{{ .Values.threatdetection.driver.gvisor.runsc.config }}
      name: runsc-config
    - mountPath: /gvisor-config
      name: falco-gvisor-config
{{- end -}}


{{- define "falcoctl.initContainer" -}}
- name: falcoctl-artifact-install
  image: {{ include "falcoctl.image" . }}
  imagePullPolicy: {{ .Values.threatdetection.falcoctl.image.pullPolicy }}
  args: 
    - artifact
    - install
  {{- with .Values.threatdetection.falcoctl.artifact.install.args }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.threatdetection.falcoctl.artifact.install.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  securityContext:
  {{- if .Values.threatdetection.falcoctl.artifact.install.securityContext }}
    {{- toYaml .Values.threatdetection.falcoctl.artifact.install.securityContext | nindent 4 }}
  {{- end }}
  volumeMounts:
    - mountPath: {{ .Values.threatdetection.falcoctl.config.artifact.install.pluginsDir }}
      name: plugins-install-dir
    - mountPath: {{ .Values.threatdetection.falcoctl.config.artifact.install.rulesfilesDir }}
      name: rulesfiles-install-dir
    - mountPath: /etc/falcoctl
      name: falcoctl-config-volume
      {{- with .Values.threatdetection.falcoctl.artifact.install.mounts.volumeMounts }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
  {{- if .Values.threatdetection.falcoctl.artifact.install.env }}
  env:
  {{- include "kubernetes-agent.renderTemplate" ( dict "value" .Values.threatdetection.falcoctl.artifact.install.env "context" $) | nindent 4 }}
  {{- end }}
  {{- if .Values.threatdetection.falcoctl.artifact.install.envFrom }}
  envFrom:
  {{- include "kubernetes-agent.renderTemplate" ( dict "value" .Values.threatdetection.falcoctl.artifact.install.envFrom "context" $) | nindent 4 }}
  {{- end }}
{{- end -}}

{{- define "falcoctl.sidecar" -}}
- name: falcoctl-artifact-follow
  image: {{ include "falcoctl.image" . }}
  imagePullPolicy: {{ .Values.threatdetection.falcoctl.image.pullPolicy }}
  args:
    - artifact
    - follow
  {{- with .Values.threatdetection.falcoctl.artifact.follow.args }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.threatdetection.falcoctl.artifact.follow.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  securityContext:
  {{- if .Values.threatdetection.falcoctl.artifact.follow.securityContext }}
    {{- toYaml .Values.threatdetection.falcoctl.artifact.follow.securityContext | nindent 4 }}
  {{- end }}
  volumeMounts:
    - mountPath: {{ .Values.threatdetection.falcoctl.config.artifact.follow.pluginsDir }}
      name: plugins-install-dir
    - mountPath: {{ .Values.threatdetection.falcoctl.config.artifact.follow.rulesfilesDir }}
      name: rulesfiles-install-dir
    - mountPath: /etc/falcoctl
      name: falcoctl-config-volume
      {{- with .Values.threatdetection.falcoctl.artifact.follow.mounts.volumeMounts }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
  {{- if .Values.threatdetection.falcoctl.artifact.follow.env }}
  env:
  {{- include "kubernetes-agent.renderTemplate" ( dict "value" .Values.threatdetection.falcoctl.artifact.follow.env "context" $) | nindent 4 }}
  {{- end }}
  {{- if .Values.threatdetection.falcoctl.artifact.follow.envFrom }}
  envFrom:
  {{- include "kubernetes-agent.renderTemplate" ( dict "value" .Values.threatdetection.falcoctl.artifact.follow.envFrom "context" $) | nindent 4 }}
  {{- end }}
{{- end -}}

{{/*
Based on the user input it populates the driver configuration in the falco config map.
*/}}
{{- define "threat-detection.engineConfiguration" -}}
{{- if .Values.threatdetection.driver.enabled -}}
{{- $supportedDrivers := list "kmod" "ebpf" "modern_ebpf" "gvisor" "auto" -}}
{{- $aliasDrivers := list "module" "modern-bpf" -}}
{{- if and (not (has .Values.threatdetection.driver.kind $supportedDrivers)) (not (has .Values.threatdetection.driver.kind $aliasDrivers)) -}}
{{- fail (printf "unsupported driver kind: \"%s\". Supported drivers %s, alias %s" .Values.threatdetection.driver.kind $supportedDrivers $aliasDrivers) -}}
{{- end -}}
{{- if or (eq .Values.threatdetection.driver.kind "kmod") (eq .Values.threatdetection.driver.kind "module") -}}
{{- $kmodConfig := dict "kind" "kmod" "kmod" (dict "buf_size_preset" .Values.threatdetection.driver.kmod.bufSizePreset "drop_failed_exit" .Values.threatdetection.driver.kmod.dropFailedExit) -}}
{{- $_ := set .Values.threatdetection.falco "engine" $kmodConfig -}}
{{- else if eq .Values.threatdetection.driver.kind "ebpf" -}}
{{- $ebpfConfig := dict "kind" "ebpf" "ebpf" (dict "buf_size_preset" .Values.threatdetection.driver.ebpf.bufSizePreset "drop_failed_exit" .Values.threatdetection.driver.ebpf.dropFailedExit "probe" .Values.threatdetection.driver.ebpf.path) -}}
{{- $_ := set .Values.threatdetection.falco "engine" $ebpfConfig -}}
{{- else if or (eq .Values.threatdetection.driver.kind "modern_ebpf") (eq .Values.threatdetection.driver.kind "modern-bpf") -}}
{{- $ebpfConfig := dict "kind" "modern_ebpf" "modern_ebpf" (dict "buf_size_preset" .Values.threatdetection.driver.modernEbpf.bufSizePreset "drop_failed_exit" .Values.threatdetection.driver.modernEbpf.dropFailedExit "cpus_for_each_buffer" .Values.threatdetection.driver.modernEbpf.cpusForEachBuffer) -}}
{{- $_ := set .Values.threatdetection.falco "engine" $ebpfConfig -}}
{{- else if eq .Values.threatdetection.driver.kind "gvisor" -}}
{{- $root := printf "/host%s/k8s.io" .Values.threatdetection.driver.gvisor.runsc.root -}}
{{- $gvisorConfig := dict "kind" "gvisor" "gvisor" (dict "config" "/gvisor-config/pod-init.json" "root" $root) -}}
{{- $_ := set .Values.threatdetection.falco "engine" $gvisorConfig -}}
{{- else if eq .Values.threatdetection.driver.kind "auto" -}}
{{- $engineConfig := dict "kind" "modern_ebpf" "kmod" (dict "buf_size_preset" .Values.threatdetection.driver.kmod.bufSizePreset "drop_failed_exit" .Values.threatdetection.driver.kmod.dropFailedExit) "ebpf" (dict "buf_size_preset" .Values.threatdetection.driver.ebpf.bufSizePreset "drop_failed_exit" .Values.threatdetection.driver.ebpf.dropFailedExit "probe" .Values.threatdetection.driver.ebpf.path) "modern_ebpf" (dict "buf_size_preset" .Values.threatdetection.driver.modernEbpf.bufSizePreset "drop_failed_exit" .Values.threatdetection.driver.modernEbpf.dropFailedExit "cpus_for_each_buffer" .Values.threatdetection.driver.modernEbpf.cpusForEachBuffer) -}}
{{- $_ := set .Values.threatdetection.falco "engine" $engineConfig -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
It returns "true" if the driver loader has to be enabled, otherwise false.
*/}}
{{- define "threat-detection.driverLoader.enabled" -}}
{{- if or (eq .Values.threatdetection.driver.kind "modern_ebpf") (eq .Values.threatdetection.driver.kind "modern-bpf") (eq .Values.threatdetection.driver.kind "gvisor") (not .Values.threatdetection.driver.enabled) (not .Values.threatdetection.driver.loader.enabled) -}}
false
{{- else -}}
true
{{- end -}}
{{- end -}}

{{/*
This helper is used to add the container plugin to the falco configuration.
*/}}
{{ define "threat-detection.containerPlugin" -}}
{{ if and .Values.threatdetection.driver.enabled .Values.threatdetection.collectors.enabled -}}
{{ if and (or .Values.threatdetection.collectors.docker.enabled .Values.threatdetection.collectors.crio.enabled .Values.threatdetection.collectors.containerd.enabled) .Values.threatdetection.collectors.containerEngine.enabled -}}
{{ fail "You can not enable any of the [docker, containerd, crio] collectors configuration and the containerEngine configuration at the same time. Please use the containerEngine configuration since the old configurations are deprecated." }}
{{ else if or .Values.threatdetection.collectors.docker.enabled .Values.threatdetection.collectors.crio.enabled .Values.threatdetection.collectors.containerd.enabled .Values.threatdetection.collectors.containerEngine.enabled -}}
{{ if or .Values.threatdetection.collectors.docker.enabled .Values.threatdetection.collectors.crio.enabled .Values.threatdetection.collectors.containerd.enabled -}}
{{ $_ := set .Values.threatdetection.collectors.containerEngine.engines.docker "enabled" .Values.threatdetection.collectors.docker.enabled -}}
{{ $_ = set .Values.threatdetection.collectors.containerEngine.engines.docker "sockets" (list .Values.threatdetection.collectors.docker.socket) -}}
{{ $_ = set .Values.threatdetection.collectors.containerEngine.engines.containerd "enabled" .Values.threatdetection.collectors.containerd.enabled -}}
{{ $_ = set .Values.threatdetection.collectors.containerEngine.engines.containerd "sockets" (list .Values.threatdetection.collectors.containerd.socket) -}}
{{ $_ = set .Values.threatdetection.collectors.containerEngine.engines.cri "enabled" .Values.threatdetection.collectors.crio.enabled -}}
{{ $_ = set .Values.threatdetection.collectors.containerEngine.engines.cri "sockets" (list .Values.threatdetection.collectors.crio.socket) -}}
{{ $_ = set .Values.threatdetection.collectors.containerEngine.engines.podman "enabled" false -}}
{{ $_ = set .Values.threatdetection.collectors.containerEngine.engines.lxc "enabled" false -}}
{{ $_ = set .Values.threatdetection.collectors.containerEngine.engines.libvirt_lxc "enabled" false -}}
{{ $_ = set .Values.threatdetection.collectors.containerEngine.engines.bpm "enabled" false -}}
{{ end -}}
{{ $hasConfig := false -}}
{{ range .Values.threatdetection.plugins -}}
{{ if eq (get . "name") "container" -}}
{{ $hasConfig = true -}}
{{ end -}}
{{ end -}}
{{ if not $hasConfig -}}
{{ $pluginConfig := dict -}}
{{ with .Values.threatdetection.collectors.containerEngine -}}
{{ $pluginConfig = dict "name" "container" "library_path" "libcontainer.so" "init_config" (dict "label_max_len" .labelMaxLen "with_size" .withSize "hooks" .hooks "engines" .engines) -}}
{{ end -}}
{{ $newConfig := append .Values.threatdetection.falco.plugins $pluginConfig -}}
{{ $_ := set .Values.threatdetection.falco "plugins" ($newConfig | uniq) -}}
{{ $loadedPlugins := append .Values.threatdetection.falco.load_plugins "container" -}}
{{ $_ = set .Values.threatdetection.falco "load_plugins" ($loadedPlugins | uniq) -}}
{{ end -}}
{{ $_ := set .Values.threatdetection.falcoctl.config.artifact.install "refs" ((append .Values.threatdetection.falcoctl.config.artifact.install.refs .Values.threatdetection.collectors.containerEngine.pluginRef) | uniq) -}}
{{ $_ = set .Values.threatdetection.falcoctl.config.artifact "allowedTypes" ((append .Values.threatdetection.falcoctl.config.artifact.allowedTypes "plugin") | uniq) -}}
{{ end -}}
{{ end -}}
{{ end -}}

{{/*
This helper is used to add container plugin volumes to the falco pod.
*/}}
{{- define "threat-detection.containerPluginVolumes" -}}
{{- if and .Values.threatdetection.driver.enabled .Values.threatdetection.collectors.enabled -}}
{{- if and (or .Values.threatdetection.collectors.docker.enabled .Values.threatdetection.collectors.crio.enabled .Values.threatdetection.collectors.containerd.enabled) .Values.threatdetection.collectors.containerEngine.enabled -}}
{{ fail "You can not enable any of the [docker, containerd, crio] collectors configuration and the containerEngine configuration at the same time. Please use the containerEngine configuration since the old configurations are deprecated." }}
{{- end -}}
{{ $volumes := list -}}
{{- if .Values.threatdetection.collectors.docker.enabled -}}
{{ $volumes = append $volumes (dict "name" "docker-socket" "hostPath" (dict "path" .Values.threatdetection.collectors.docker.socket)) -}}
{{- end -}}
{{- if .Values.threatdetection.collectors.crio.enabled -}}
{{ $volumes = append $volumes (dict "name" "crio-socket" "hostPath" (dict "path" .Values.threatdetection.collectors.crio.socket)) -}}
{{- end -}}
{{- if .Values.threatdetection.collectors.containerd.enabled -}}
{{ $volumes = append $volumes (dict "name" "containerd-socket" "hostPath" (dict "path" .Values.threatdetection.collectors.containerd.socket)) -}}
{{- end -}}
{{- if .Values.threatdetection.collectors.containerEngine.enabled -}}
{{- $seenPaths := dict -}}
{{- $idx := 0 -}}
{{- $engineOrder := list "docker" "podman" "containerd" "cri" "lxc" "libvirt_lxc" "bpm" -}}
{{- range $engineName := $engineOrder -}}
{{- $val := index $.Values.threatdetection.collectors.containerEngine.engines $engineName -}}
{{- if and $val $val.enabled -}}
{{- range $index, $socket := $val.sockets -}}
{{- $mountPath := print "/host" $socket -}}
{{- if not (hasKey $seenPaths $mountPath) -}}
{{ $volumes = append $volumes (dict "name" (printf "container-engine-socket-%d" $idx) "hostPath" (dict "path" $socket)) -}}
{{- $idx = add $idx 1 -}}
{{- $_ := set $seenPaths $mountPath true -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if gt (len $volumes) 0 -}}
{{ toYaml $volumes -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
This helper is used to add container plugin volumeMounts to the falco pod.
*/}}
{{- define "threat-detection.containerPluginVolumeMounts" -}}
{{- if and .Values.threatdetection.driver.enabled .Values.threatdetection.collectors.enabled -}}
{{- if and (or .Values.threatdetection.collectors.docker.enabled .Values.threatdetection.collectors.crio.enabled .Values.threatdetection.collectors.containerd.enabled) .Values.threatdetection.collectors.containerEngine.enabled -}}
{{ fail "You can not enable any of the [docker, containerd, crio] collectors configuration and the containerEngine configuration at the same time. Please use the containerEngine configuration since the old configurations are deprecated." }}
{{- end -}}
{{ $volumeMounts := list -}}
{{- if .Values.threatdetection.collectors.docker.enabled -}}
{{ $volumeMounts = append $volumeMounts (dict "name" "docker-socket" "mountPath" (print "/host" .Values.threatdetection.collectors.docker.socket)) -}}
{{- end -}}
{{- if .Values.threatdetection.collectors.crio.enabled -}}
{{ $volumeMounts = append $volumeMounts (dict "name" "crio-socket" "mountPath" (print "/host" .Values.threatdetection.collectors.crio.socket)) -}}
{{- end -}}
{{- if .Values.threatdetection.collectors.containerd.enabled -}}
{{ $volumeMounts = append $volumeMounts (dict "name" "containerd-socket" "mountPath" (print "/host" .Values.threatdetection.collectors.containerd.socket)) -}}
{{- end -}}
{{- if .Values.threatdetection.collectors.containerEngine.enabled -}}
{{- $seenPaths := dict -}}
{{- $idx := 0 -}}
{{- $engineOrder := list "docker" "podman" "containerd" "cri" "lxc" "libvirt_lxc" "bpm" -}}
{{- range $engineName := $engineOrder -}}
{{- $val := index $.Values.threatdetection.collectors.containerEngine.engines $engineName -}}
{{- if and $val $val.enabled -}}
{{- range $index, $socket := $val.sockets -}}
{{- $mountPath := print "/host" $socket -}}
{{- if not (hasKey $seenPaths $mountPath) -}}
{{ $volumeMounts = append $volumeMounts (dict "name" (printf "container-engine-socket-%d" $idx) "mountPath" $mountPath) -}}
{{- $idx = add $idx 1 -}}
{{- $_ := set $seenPaths $mountPath true -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if gt (len $volumeMounts) 0 -}}
{{ toYaml ($volumeMounts) }}
{{- end -}}
{{- end -}}
{{- end -}}
