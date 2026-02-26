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
app.kubernetes.io/version: {{ .Values.agent.image.tag | quote }}
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

{{- define "tdr.name" -}}
{{- printf "%s-tdr" (include "kubernetes-agent.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tdr.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubernetes-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: tdr
{{- end }}

{{/*
Threat detection labels
*/}}
{{- define "tdr.labels" -}}
helm.sh/chart: {{ include "kubernetes-agent.chart" . }}
{{ include "tdr.selectorLabels" . }}
{{- if .Values.tdr.image.tag }}
app.kubernetes.io/version: {{ .Values.tdr.image.tag | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "tdr.serviceAccountName" -}}
{{- if .Values.tdr.serviceAccount.create }}
{{- default (include "tdr.name" .) .Values.tdr.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.tdr.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the proper Falco image name
*/}}
{{- define "tdr.image" -}}
{{- with .Values.tdr.image.registry -}}
    {{- . }}/
{{- end -}}
{{- .Values.tdr.image.repository }}:
{{- .Values.tdr.image.tag -}}
{{- end -}}

{{/*
Return the proper Falco driver loader image name
*/}}
{{- define "tdr.driverLoader.image" -}}
{{- with .Values.tdr.driver.loader.initContainer.image.registry -}}
    {{- . }}/
{{- end -}}
{{- .Values.tdr.driver.loader.initContainer.image.repository }}:
{{- .Values.tdr.driver.loader.initContainer.image.tag | default .Chart.AppVersion -}}
{{- end -}}

{{/*
Return the proper Falcoctl image name
*/}}
{{- define "falcoctl.image" -}}
{{ printf "%s/%s:%s" .Values.tdr.falcoctl.image.registry .Values.tdr.falcoctl.image.repository .Values.tdr.falcoctl.image.tag }}
{{- end -}}

{{/*
Extract the unixSocket's directory path
*/}}
{{- define "tdr.unixSocketDir" -}}
{{- if and .Values.tdr.grpc.enabled .Values.tdr.grpc.bind_address (hasPrefix "unix://" .Values.tdr.grpc.bind_address) -}}
{{- .Values.tdr.grpc.bind_address | trimPrefix "unix://" | dir -}}
{{- end -}}
{{- end -}}

{{/*
Disable the syscall source if some conditions are met.
By default the syscall source is always enabled in threat-detection. If no syscall source is enabled, falco
exits. Here we check that no producers for syscalls event has been configured, and if true
we just disable the sycall source.
*/}}
{{- define "tdr.configSyscallSource" -}}
{{- $userspaceDisabled := true -}}
{{- $gvisorDisabled := (ne .Values.tdr.driver.kind  "gvisor") -}}
{{- $driverDisabled :=  (not .Values.tdr.driver.enabled) -}}
{{- if or (has "-u" .Values.tdr.extra.args) (has "--userspace" .Values.tdr.extra.args) -}}
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
{{- define "tdr.gvisor.initContainer" -}}
- name: {{ .Chart.Name }}-gvisor-init
  image: {{ include "tdr.image" . }}
  imagePullPolicy: {{ .Values.tdr.image.pullPolicy }}
  args:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      root={{ .Values.tdr.driver.gvisor.runsc.root }}
      config={{ .Values.tdr.driver.gvisor.runsc.config }}

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
    - mountPath: /host{{ .Values.tdr.driver.gvisor.runsc.path }}
      name: runsc-path
      readOnly: true
    - mountPath: /host{{ .Values.tdr.driver.gvisor.runsc.root }}
      name: runsc-root
    - mountPath: /host{{ .Values.tdr.driver.gvisor.runsc.config }}
      name: runsc-config
    - mountPath: /gvisor-config
      name: falco-gvisor-config
{{- end -}}


{{- define "falcoctl.initContainer" -}}
- name: falcoctl-artifact-install
  image: {{ include "falcoctl.image" . }}
  imagePullPolicy: {{ .Values.tdr.falcoctl.image.pullPolicy }}
  args: 
    - artifact
    - install
  {{- with .Values.tdr.falcoctl.artifact.install.args }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tdr.falcoctl.artifact.install.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  securityContext:
  {{- if .Values.tdr.falcoctl.artifact.install.securityContext }}
    {{- toYaml .Values.tdr.falcoctl.artifact.install.securityContext | nindent 4 }}
  {{- end }}
  volumeMounts:
    - mountPath: {{ .Values.tdr.falcoctl.config.artifact.install.pluginsDir }}
      name: plugins-install-dir
    - mountPath: {{ .Values.tdr.falcoctl.config.artifact.install.rulesfilesDir }}
      name: rulesfiles-install-dir
    - mountPath: /etc/falcoctl
      name: falcoctl-config-volume
      {{- with .Values.tdr.falcoctl.artifact.install.mounts.volumeMounts }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
  {{- if .Values.tdr.falcoctl.artifact.install.env }}
  env:
  {{- include "kubernetes-agent.renderTemplate" ( dict "value" .Values.tdr.falcoctl.artifact.install.env "context" $) | nindent 4 }}
  {{- end }}
  {{- if .Values.tdr.falcoctl.artifact.install.envFrom }}
  envFrom:
  {{- include "kubernetes-agent.renderTemplate" ( dict "value" .Values.tdr.falcoctl.artifact.install.envFrom "context" $) | nindent 4 }}
  {{- end }}
{{- end -}}

{{- define "falcoctl.sidecar" -}}
- name: falcoctl-artifact-follow
  image: {{ include "falcoctl.image" . }}
  imagePullPolicy: {{ .Values.tdr.falcoctl.image.pullPolicy }}
  args:
    - artifact
    - follow
  {{- with .Values.tdr.falcoctl.artifact.follow.args }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tdr.falcoctl.artifact.follow.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  securityContext:
  {{- if .Values.tdr.falcoctl.artifact.follow.securityContext }}
    {{- toYaml .Values.tdr.falcoctl.artifact.follow.securityContext | nindent 4 }}
  {{- end }}
  volumeMounts:
    - mountPath: {{ .Values.tdr.falcoctl.config.artifact.follow.pluginsDir }}
      name: plugins-install-dir
    - mountPath: {{ .Values.tdr.falcoctl.config.artifact.follow.rulesfilesDir }}
      name: rulesfiles-install-dir
    - mountPath: /etc/falcoctl
      name: falcoctl-config-volume
      {{- with .Values.tdr.falcoctl.artifact.follow.mounts.volumeMounts }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
  {{- if .Values.tdr.falcoctl.artifact.follow.env }}
  env:
  {{- include "kubernetes-agent.renderTemplate" ( dict "value" .Values.tdr.falcoctl.artifact.follow.env "context" $) | nindent 4 }}
  {{- end }}
  {{- if .Values.tdr.falcoctl.artifact.follow.envFrom }}
  envFrom:
  {{- include "kubernetes-agent.renderTemplate" ( dict "value" .Values.tdr.falcoctl.artifact.follow.envFrom "context" $) | nindent 4 }}
  {{- end }}
{{- end -}}

{{/*
Based on the user input it populates the driver configuration in the falco config map.
*/}}
{{- define "tdr.engineConfiguration" -}}
{{- if .Values.tdr.driver.enabled -}}
{{- $supportedDrivers := list "kmod" "ebpf" "modern_ebpf" "gvisor" "auto" -}}
{{- $aliasDrivers := list "module" "modern-bpf" -}}
{{- if and (not (has .Values.tdr.driver.kind $supportedDrivers)) (not (has .Values.tdr.driver.kind $aliasDrivers)) -}}
{{- fail (printf "unsupported driver kind: \"%s\". Supported drivers %s, alias %s" .Values.tdr.driver.kind $supportedDrivers $aliasDrivers) -}}
{{- end -}}
{{- if or (eq .Values.tdr.driver.kind "kmod") (eq .Values.tdr.driver.kind "module") -}}
{{- $kmodConfig := dict "kind" "kmod" "kmod" (dict "buf_size_preset" .Values.tdr.driver.kmod.bufSizePreset "drop_failed_exit" .Values.tdr.driver.kmod.dropFailedExit) -}}
{{- $_ := set .Values.tdr.falco "engine" $kmodConfig -}}
{{- else if eq .Values.tdr.driver.kind "ebpf" -}}
{{- $ebpfConfig := dict "kind" "ebpf" "ebpf" (dict "buf_size_preset" .Values.tdr.driver.ebpf.bufSizePreset "drop_failed_exit" .Values.tdr.driver.ebpf.dropFailedExit "probe" .Values.tdr.driver.ebpf.path) -}}
{{- $_ := set .Values.tdr.falco "engine" $ebpfConfig -}}
{{- else if or (eq .Values.tdr.driver.kind "modern_ebpf") (eq .Values.tdr.driver.kind "modern-bpf") -}}
{{- $ebpfConfig := dict "kind" "modern_ebpf" "modern_ebpf" (dict "buf_size_preset" .Values.tdr.driver.modernEbpf.bufSizePreset "drop_failed_exit" .Values.tdr.driver.modernEbpf.dropFailedExit "cpus_for_each_buffer" .Values.tdr.driver.modernEbpf.cpusForEachBuffer) -}}
{{- $_ := set .Values.tdr.falco "engine" $ebpfConfig -}}
{{- else if eq .Values.tdr.driver.kind "gvisor" -}}
{{- $root := printf "/host%s/k8s.io" .Values.tdr.driver.gvisor.runsc.root -}}
{{- $gvisorConfig := dict "kind" "gvisor" "gvisor" (dict "config" "/gvisor-config/pod-init.json" "root" $root) -}}
{{- $_ := set .Values.tdr.falco "engine" $gvisorConfig -}}
{{- else if eq .Values.tdr.driver.kind "auto" -}}
{{- $engineConfig := dict "kind" "modern_ebpf" "kmod" (dict "buf_size_preset" .Values.tdr.driver.kmod.bufSizePreset "drop_failed_exit" .Values.tdr.driver.kmod.dropFailedExit) "ebpf" (dict "buf_size_preset" .Values.tdr.driver.ebpf.bufSizePreset "drop_failed_exit" .Values.tdr.driver.ebpf.dropFailedExit "probe" .Values.tdr.driver.ebpf.path) "modern_ebpf" (dict "buf_size_preset" .Values.tdr.driver.modernEbpf.bufSizePreset "drop_failed_exit" .Values.tdr.driver.modernEbpf.dropFailedExit "cpus_for_each_buffer" .Values.tdr.driver.modernEbpf.cpusForEachBuffer) -}}
{{- $_ := set .Values.tdr.falco "engine" $engineConfig -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
It returns "true" if the driver loader has to be enabled, otherwise false.
*/}}
{{- define "tdr.driverLoader.enabled" -}}
{{- if or (eq .Values.tdr.driver.kind "modern_ebpf") (eq .Values.tdr.driver.kind "modern-bpf") (eq .Values.tdr.driver.kind "gvisor") (not .Values.tdr.driver.enabled) (not .Values.tdr.driver.loader.enabled) -}}
false
{{- else -}}
true
{{- end -}}
{{- end -}}

{{/*
This helper is used to add the container plugin to the falco configuration.
*/}}
{{ define "tdr.containerPlugin" -}}
{{ if and .Values.tdr.driver.enabled .Values.tdr.collectors.enabled -}}
{{ if and (or .Values.tdr.collectors.docker.enabled .Values.tdr.collectors.crio.enabled .Values.tdr.collectors.containerd.enabled) .Values.tdr.collectors.containerEngine.enabled -}}
{{ fail "You can not enable any of the [docker, containerd, crio] collectors configuration and the containerEngine configuration at the same time. Please use the containerEngine configuration since the old configurations are deprecated." }}
{{ else if or .Values.tdr.collectors.docker.enabled .Values.tdr.collectors.crio.enabled .Values.tdr.collectors.containerd.enabled .Values.tdr.collectors.containerEngine.enabled -}}
{{ if or .Values.tdr.collectors.docker.enabled .Values.tdr.collectors.crio.enabled .Values.tdr.collectors.containerd.enabled -}}
{{ $_ := set .Values.tdr.collectors.containerEngine.engines.docker "enabled" .Values.tdr.collectors.docker.enabled -}}
{{ $_ = set .Values.tdr.collectors.containerEngine.engines.docker "sockets" (list .Values.tdr.collectors.docker.socket) -}}
{{ $_ = set .Values.tdr.collectors.containerEngine.engines.containerd "enabled" .Values.tdr.collectors.containerd.enabled -}}
{{ $_ = set .Values.tdr.collectors.containerEngine.engines.containerd "sockets" (list .Values.tdr.collectors.containerd.socket) -}}
{{ $_ = set .Values.tdr.collectors.containerEngine.engines.cri "enabled" .Values.tdr.collectors.crio.enabled -}}
{{ $_ = set .Values.tdr.collectors.containerEngine.engines.cri "sockets" (list .Values.tdr.collectors.crio.socket) -}}
{{ $_ = set .Values.tdr.collectors.containerEngine.engines.podman "enabled" false -}}
{{ $_ = set .Values.tdr.collectors.containerEngine.engines.lxc "enabled" false -}}
{{ $_ = set .Values.tdr.collectors.containerEngine.engines.libvirt_lxc "enabled" false -}}
{{ $_ = set .Values.tdr.collectors.containerEngine.engines.bpm "enabled" false -}}
{{ end -}}
{{ $hasConfig := false -}}
{{ range .Values.tdr.plugins -}}
{{ if eq (get . "name") "container" -}}
{{ $hasConfig = true -}}
{{ end -}}
{{ end -}}
{{ if not $hasConfig -}}
{{ $pluginConfig := dict -}}
{{ with .Values.tdr.collectors.containerEngine -}}
{{ $pluginConfig = dict "name" "container" "library_path" "libcontainer.so" "init_config" (dict "label_max_len" .labelMaxLen "with_size" .withSize "hooks" .hooks "engines" .engines) -}}
{{ end -}}
{{ $newConfig := append .Values.tdr.falco.plugins $pluginConfig -}}
{{ $_ := set .Values.tdr.falco "plugins" ($newConfig | uniq) -}}
{{ $loadedPlugins := append .Values.tdr.falco.load_plugins "container" -}}
{{ $_ = set .Values.tdr.falco "load_plugins" ($loadedPlugins | uniq) -}}
{{ end -}}
{{ $_ := set .Values.tdr.falcoctl.config.artifact.install "refs" ((append .Values.tdr.falcoctl.config.artifact.install.refs .Values.tdr.collectors.containerEngine.pluginRef) | uniq) -}}
{{ $_ = set .Values.tdr.falcoctl.config.artifact "allowedTypes" ((append .Values.tdr.falcoctl.config.artifact.allowedTypes "plugin") | uniq) -}}
{{ end -}}
{{ end -}}
{{ end -}}

{{/*
This helper is used to add container plugin volumes to the falco pod.
*/}}
{{- define "tdr.containerPluginVolumes" -}}
{{- if and .Values.tdr.driver.enabled .Values.tdr.collectors.enabled -}}
{{- if and (or .Values.tdr.collectors.docker.enabled .Values.tdr.collectors.crio.enabled .Values.tdr.collectors.containerd.enabled) .Values.tdr.collectors.containerEngine.enabled -}}
{{ fail "You can not enable any of the [docker, containerd, crio] collectors configuration and the containerEngine configuration at the same time. Please use the containerEngine configuration since the old configurations are deprecated." }}
{{- end -}}
{{ $volumes := list -}}
{{- if .Values.tdr.collectors.docker.enabled -}}
{{ $volumes = append $volumes (dict "name" "docker-socket" "hostPath" (dict "path" .Values.tdr.collectors.docker.socket)) -}}
{{- end -}}
{{- if .Values.tdr.collectors.crio.enabled -}}
{{ $volumes = append $volumes (dict "name" "crio-socket" "hostPath" (dict "path" .Values.tdr.collectors.crio.socket)) -}}
{{- end -}}
{{- if .Values.tdr.collectors.containerd.enabled -}}
{{ $volumes = append $volumes (dict "name" "containerd-socket" "hostPath" (dict "path" .Values.tdr.collectors.containerd.socket)) -}}
{{- end -}}
{{- if .Values.tdr.collectors.containerEngine.enabled -}}
{{- $seenPaths := dict -}}
{{- $idx := 0 -}}
{{- $engineOrder := list "docker" "podman" "containerd" "cri" "lxc" "libvirt_lxc" "bpm" -}}
{{- range $engineName := $engineOrder -}}
{{- $val := index $.Values.tdr.collectors.containerEngine.engines $engineName -}}
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
{{- define "tdr.containerPluginVolumeMounts" -}}
{{- if and .Values.tdr.driver.enabled .Values.tdr.collectors.enabled -}}
{{- if and (or .Values.tdr.collectors.docker.enabled .Values.tdr.collectors.crio.enabled .Values.tdr.collectors.containerd.enabled) .Values.tdr.collectors.containerEngine.enabled -}}
{{ fail "You can not enable any of the [docker, containerd, crio] collectors configuration and the containerEngine configuration at the same time. Please use the containerEngine configuration since the old configurations are deprecated." }}
{{- end -}}
{{ $volumeMounts := list -}}
{{- if .Values.tdr.collectors.docker.enabled -}}
{{ $volumeMounts = append $volumeMounts (dict "name" "docker-socket" "mountPath" (print "/host" .Values.tdr.collectors.docker.socket)) -}}
{{- end -}}
{{- if .Values.tdr.collectors.crio.enabled -}}
{{ $volumeMounts = append $volumeMounts (dict "name" "crio-socket" "mountPath" (print "/host" .Values.tdr.collectors.crio.socket)) -}}
{{- end -}}
{{- if .Values.tdr.collectors.containerd.enabled -}}
{{ $volumeMounts = append $volumeMounts (dict "name" "containerd-socket" "mountPath" (print "/host" .Values.tdr.collectors.containerd.socket)) -}}
{{- end -}}
{{- if .Values.tdr.collectors.containerEngine.enabled -}}
{{- $seenPaths := dict -}}
{{- $idx := 0 -}}
{{- $engineOrder := list "docker" "podman" "containerd" "cri" "lxc" "libvirt_lxc" "bpm" -}}
{{- range $engineName := $engineOrder -}}
{{- $val := index $.Values.tdr.collectors.containerEngine.engines $engineName -}}
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
