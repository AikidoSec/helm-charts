{{- define "tdr.podTemplate" -}}
metadata:
  name: {{ include "tdr.name" . }}
  labels:
    {{- include "tdr.selectorLabels" . | nindent 4 }}
    {{- with .Values.tdr.podLabels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    checksum/config: {{ include (print $.Template.BasePath "/tdr/configmap.yaml") . | sha256sum }}
    {{- if .Values.tdr.driver.enabled }}
    {{- if (or (eq .Values.tdr.driver.kind "modern_ebpf") (eq .Values.tdr.driver.kind "modern-bpf")) }}
    {{- if .Values.tdr.driver.modernEbpf.leastPrivileged }}
    container.apparmor.security.beta.kubernetes.io/{{ .Chart.Name }}: unconfined
    {{- end }}
    {{- else if eq .Values.tdr.driver.kind "ebpf" }}
    {{- if .Values.tdr.driver.ebpf.leastPrivileged }}
    container.apparmor.security.beta.kubernetes.io/{{ .Chart.Name }}: unconfined
    {{- end }}
    {{- end }}
    {{- end }}
    {{- with .Values.tdr.podAnnotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- if .Values.tdr.falco.podHostname }}
  hostname: {{ .Values.tdr.falco.podHostname }}
  {{- end }}
  serviceAccountName: {{ include "tdr.serviceAccountName" . }}
  {{- with .Values.tdr.podSecurityContext }}
  securityContext:
    {{- toYaml . | nindent 4}}
  {{- end }}
  {{- if .Values.tdr.driver.enabled }}
  {{- if and (eq .Values.tdr.driver.kind "ebpf") .Values.tdr.driver.ebpf.hostNetwork }}
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  {{- end }}
  {{- end }}
  {{- if .Values.tdr.podPriorityClassName }}
  priorityClassName: {{ .Values.tdr.podPriorityClassName }}
  {{- end }}
  {{- with .Values.tdr.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tdr.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tdr.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if eq .Values.tdr.driver.kind "gvisor" }}
  hostNetwork: true
  hostPID: true
  dnsPolicy: ClusterFirstWithHostNet
  {{- end }}
  containers:
    - name: {{ .Chart.Name }}
      image: {{ include "tdr.image" . }}
      imagePullPolicy: {{ .Values.tdr.image.pullPolicy }}
      resources:
        {{- toYaml .Values.tdr.resources | nindent 8 }}
      securityContext:
        {{- include "tdr.securityContext" . | nindent 8 }}
      args:
        - /usr/bin/falco
        {{- include "tdr.configSyscallSource" . | indent 8 }}
    {{- with .Values.tdr.extra.args }}
      {{- toYaml . | nindent 8 }}
    {{- end }}
      env:
        - name: HOST_ROOT
          value: /host
        - name: FALCO_HOSTNAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: FALCO_K8S_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
      {{- if .Values.tdr.extra.env }}
      {{- include "kubernetes-agent.renderTemplate" ( dict "value" .Values.tdr.extra.env "context" $) | nindent 8 }}
      {{- end }}
      {{- if .Values.tdr.falco.webserver.enabled }}
      ports:
        - containerPort: {{ .Values.tdr.falco.webserver.listen_port }}
          name: web
          protocol: TCP
      livenessProbe:
        initialDelaySeconds: {{ .Values.tdr.healthChecks.livenessProbe.initialDelaySeconds }}
        timeoutSeconds: {{ .Values.tdr.healthChecks.livenessProbe.timeoutSeconds }}
        periodSeconds: {{ .Values.tdr.healthChecks.livenessProbe.periodSeconds }}
        failureThreshold: 45
        httpGet:
          path: {{ .Values.tdr.falco.webserver.k8s_healthz_endpoint }}
          port: {{ .Values.tdr.falco.webserver.listen_port }}
          {{- if .Values.tdr.falco.webserver.ssl_enabled }}
          scheme: HTTPS
          {{- end }}
      readinessProbe:
        initialDelaySeconds: {{ .Values.tdr.healthChecks.readinessProbe.initialDelaySeconds }}
        timeoutSeconds: {{ .Values.tdr.healthChecks.readinessProbe.timeoutSeconds }}
        periodSeconds: {{ .Values.tdr.healthChecks.readinessProbe.periodSeconds }}
        httpGet:
          path: {{ .Values.tdr.falco.webserver.k8s_healthz_endpoint }}
          port: {{ .Values.tdr.falco.webserver.listen_port }}
          {{- if .Values.tdr.falco.webserver.ssl_enabled }}
          scheme: HTTPS
          {{- end }}
      {{- end }}
      volumeMounts:
      {{- include "tdr.containerPluginVolumeMounts" . | nindent 8 -}}
      {{- if or .Values.tdr.falcoctl.artifact.install.enabled .Values.tdr.falcoctl.artifact.follow.enabled }}
      {{- if has "rulesfile" .Values.tdr.falcoctl.config.artifact.allowedTypes }}
        - mountPath: /etc/falco
          name: rulesfiles-install-dir
      {{- end }}
      {{- if has "plugin" .Values.tdr.falcoctl.config.artifact.allowedTypes }}
        - mountPath: /usr/share/falco/plugins
          name: plugins-install-dir
      {{- end }}
      {{- end }}
      {{- if eq (include "tdr.driverLoader.enabled" .) "true" }}
        - mountPath: /etc/falco/config.d
          name: specialized-falco-configs
      {{- end }}
        - mountPath: /root/.falco
          name: root-falco-fs
        - mountPath: /host/proc
          name: proc-fs
        {{- if and .Values.tdr.driver.enabled (not .Values.tdr.driver.loader.enabled) }}
          readOnly: true
        - mountPath: /host/boot
          name: boot-fs
          readOnly: true
        - mountPath: /host/lib/modules
          name: lib-modules
        - mountPath: /host/usr
          name: usr-fs
          readOnly: true
        {{- end }}
        {{- if .Values.tdr.driver.enabled }}
        - mountPath: /host/etc
          name: etc-fs
          readOnly: true
        {{- end -}}
        {{- if and .Values.tdr.driver.enabled (or (eq .Values.tdr.driver.kind "kmod") (eq .Values.tdr.driver.kind "module") (eq .Values.tdr.driver.kind "auto")) }}
        - mountPath: /host/dev
          name: dev-fs
          readOnly: true
        - name: sys-fs
          mountPath: /sys/module
        {{- end }}
        {{- if and .Values.tdr.driver.enabled (and (eq .Values.tdr.driver.kind "ebpf") (contains "falco-no-driver" .Values.tdr.image.repository)) }}
        - name: debugfs
          mountPath: /sys/kernel/debug
        {{- end }}
        - mountPath: /etc/falco/falco.yaml
          name: falco-yaml
          subPath: falco.yaml
        - mountPath: /etc/falco/aikido-rules.d
          name: aikido-rules-volume
        {{- if eq .Values.tdr.driver.kind "gvisor" }}
        - mountPath: /usr/local/bin/runsc
          name: runsc-path
          readOnly: true
        - mountPath: /host{{ .Values.tdr.driver.gvisor.runsc.root }}
          name: runsc-root
        - mountPath: /host{{ .Values.tdr.driver.gvisor.runsc.config }}
          name: runsc-config
        - mountPath: /gvisor-config
          name: falco-gvisor-config
        {{- end }}
  {{- if .Values.tdr.falcoctl.artifact.follow.enabled }}
    {{- include "falcoctl.sidecar" . | nindent 4 }}
  {{- end }}
  initContainers:
  {{- with .Values.tdr.extra.initContainers }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if eq .Values.tdr.driver.kind "gvisor" }}
  {{- include "tdr.gvisor.initContainer" . | nindent 4 }}
  {{- end }}
  {{- if eq (include "tdr.driverLoader.enabled" .) "true" }}
    {{- include "tdr.driverLoader.initContainer" . | nindent 4 }}
  {{- end }}
  {{- if .Values.tdr.falcoctl.artifact.install.enabled }}
    {{- include "falcoctl.initContainer" . | nindent 4 }}
  {{- end }}
  volumes:
    {{- include "tdr.containerPluginVolumes" . | nindent 4 -}}
    {{- if eq (include "tdr.driverLoader.enabled" .) "true" }}
    - name: specialized-falco-configs
      emptyDir: {}
    {{- end }}
    {{- if or .Values.tdr.falcoctl.artifact.install.enabled .Values.tdr.falcoctl.artifact.follow.enabled }}
    - name: plugins-install-dir
      emptyDir: {}
    - name: rulesfiles-install-dir
      emptyDir: {}
    {{- end }}
    - name: root-falco-fs
      emptyDir: {}
    {{- if .Values.tdr.driver.enabled }}  
    - name: boot-fs
      hostPath:
        path: /boot
    - name: lib-modules
      hostPath:
        path: /lib/modules
    - name: usr-fs
      hostPath:
        path: /usr
    - name: etc-fs
      hostPath:
        path: /etc
    {{- end }}
    {{- if and .Values.tdr.driver.enabled (or (eq .Values.tdr.driver.kind "kmod") (eq .Values.tdr.driver.kind "module") (eq .Values.tdr.driver.kind "auto")) }}
    - name: dev-fs
      hostPath:
        path: /dev
    - name: sys-fs
      hostPath:
        path: /sys/module
    {{- end }}
    {{- if and .Values.tdr.driver.enabled (and (eq .Values.tdr.driver.kind "ebpf") (contains "falco-no-driver" .Values.tdr.image.repository)) }}
    - name: debugfs
      hostPath:
        path: /sys/kernel/debug
    {{- end }}
    - name: proc-fs
      hostPath:
        path: /proc
    {{- if eq .Values.tdr.driver.kind "gvisor" }}
    - name: runsc-path
      hostPath:
        path: {{ .Values.tdr.driver.gvisor.runsc.path }}/runsc
        type: File
    - name: runsc-root
      hostPath:
        path: {{ .Values.tdr.driver.gvisor.runsc.root }}
    - name: runsc-config
      hostPath:
        path: {{ .Values.tdr.driver.gvisor.runsc.config }}
        type: File
    - name: falco-gvisor-config
      emptyDir: {}
    {{- end }}
    - name: falcoctl-config-volume
      configMap: 
        name: {{ include "tdr.name" . }}-falcoctl
        items:
          - key: falcoctl.yaml
            path: falcoctl.yaml
    - name: falco-yaml
      configMap:
        name: {{ include "tdr.name" . }}
        items:
        - key: falco.yaml
          path: falco.yaml
    - name: aikido-rules-volume
      configMap:
        name: {{ include "tdr.name" . }}-custom-rules
    {{- end -}}

{{- define "tdr.driverLoader.initContainer" -}}
- name: {{ .Chart.Name }}-driver-loader
  image: {{ include "tdr.driverLoader.image" . }}
  imagePullPolicy: {{ .Values.tdr.driver.loader.initContainer.image.pullPolicy }}
  args:
  {{- with .Values.tdr.driver.loader.initContainer.args }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if eq .Values.tdr.driver.kind "module" }}
    - kmod
  {{- else if eq .Values.tdr.driver.kind "modern-bpf"}}
    - modern_ebpf
  {{- else }}
    - {{ .Values.tdr.driver.kind }}
  {{- end }}
  {{- with .Values.tdr.driver.loader.initContainer.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  securityContext:
  {{- if .Values.tdr.driver.loader.initContainer.securityContext }}
    {{- toYaml .Values.tdr.driver.loader.initContainer.securityContext | nindent 4 }}
  {{- else if (or (eq .Values.tdr.driver.kind "kmod") (eq .Values.tdr.driver.kind "module") (eq .Values.tdr.driver.kind "auto")) }}
    privileged: true
  {{- end }}
  volumeMounts:
    - mountPath: /root/.falco
      name: root-falco-fs
    - mountPath: /host/proc
      name: proc-fs
      readOnly: true
    - mountPath: /host/boot
      name: boot-fs
      readOnly: true
    - mountPath: /host/lib/modules
      name: lib-modules
    - mountPath: /host/usr
      name: usr-fs
      readOnly: true
    - mountPath: /host/etc
      name: etc-fs
      readOnly: true
    - mountPath: /etc/falco/config.d
      name: specialized-falco-configs
  env:
    - name: HOST_ROOT
      value: /host
  {{- if .Values.tdr.driver.loader.initContainer.env }}
  {{- include "kubernetes-agent.renderTemplate" ( dict "value" .Values.tdr.driver.loader.initContainer.env "context" $) | nindent 4 }}
  {{- end }}
  {{- if eq .Values.tdr.driver.kind "auto" }}
    - name: FALCOCTL_DRIVER_CONFIG_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: FALCOCTL_DRIVER_CONFIG_CONFIGMAP
      value: {{ include "tdr.name" . }}
  {{- else }}
    - name: FALCOCTL_DRIVER_CONFIG_UPDATE_FALCO
      value: "false"
  {{- end }}
{{- end -}}

{{- define "tdr.securityContext" -}}
{{- $securityContext := dict -}}
{{- if .Values.tdr.driver.enabled -}}
  {{- if (or (eq .Values.tdr.driver.kind "kmod") (eq .Values.tdr.driver.kind "module") (eq .Values.tdr.driver.kind "auto")) -}}
    {{- $securityContext := set $securityContext "privileged" true -}}
  {{- end -}}
  {{- if eq .Values.tdr.driver.kind "ebpf" -}}
    {{- if .Values.tdr.driver.ebpf.leastPrivileged -}}
      {{- $securityContext := set $securityContext "capabilities" (dict "add" (list "SYS_ADMIN" "SYS_RESOURCE" "SYS_PTRACE")) -}}
    {{- else -}}
      {{- $securityContext := set $securityContext "privileged" true -}}
    {{- end -}}
  {{- end -}}
  {{- if (or (eq .Values.tdr.driver.kind "modern_ebpf") (eq .Values.tdr.driver.kind "modern-bpf")) -}}
    {{- if .Values.tdr.driver.modernEbpf.leastPrivileged -}}
      {{- $securityContext := set $securityContext "capabilities" (dict "add" (list "BPF" "SYS_RESOURCE" "PERFMON" "SYS_PTRACE")) -}}
    {{- else -}}
      {{- $securityContext := set $securityContext "privileged" true -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if not (empty (.Values.tdr.containerSecurityContext)) -}}
  {{-  toYaml .Values.tdr.containerSecurityContext }}
{{- else -}}
  {{- toYaml $securityContext }}
{{- end -}}
{{- end -}}
