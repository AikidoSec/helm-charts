{{- define "threat-detection.podTemplate" -}}
metadata:
  name: {{ include "threat-detection.name" . }}
  labels:
    {{- include "threat-detection.selectorLabels" . | nindent 4 }}
    {{- with .Values.threatdetection.podLabels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    checksum/config: {{ include (print $.Template.BasePath "/threat-detection/configmap.yaml") . | sha256sum }}
    {{- if .Values.threatdetection.driver.enabled }}
    {{- if (or (eq .Values.threatdetection.driver.kind "modern_ebpf") (eq .Values.threatdetection.driver.kind "modern-bpf")) }}
    {{- if .Values.threatdetection.driver.modernEbpf.leastPrivileged }}
    container.apparmor.security.beta.kubernetes.io/{{ .Chart.Name }}: unconfined
    {{- end }}
    {{- else if eq .Values.threatdetection.driver.kind "ebpf" }}
    {{- if .Values.threatdetection.driver.ebpf.leastPrivileged }}
    container.apparmor.security.beta.kubernetes.io/{{ .Chart.Name }}: unconfined
    {{- end }}
    {{- end }}
    {{- end }}
    {{- with .Values.threatdetection.podAnnotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- if .Values.threatdetection.falco.podHostname }}
  hostname: {{ .Values.threatdetection.falco.podHostname }}
  {{- end }}
  serviceAccountName: {{ include "threat-detection.serviceAccountName" . }}
  {{- with .Values.threatdetection.podSecurityContext }}
  securityContext:
    {{- toYaml . | nindent 4}}
  {{- end }}
  {{- if .Values.threatdetection.driver.enabled }}
  {{- if and (eq .Values.threatdetection.driver.kind "ebpf") .Values.threatdetection.driver.ebpf.hostNetwork }}
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  {{- end }}
  {{- end }}
  {{- if .Values.threatdetection.podPriorityClassName }}
  priorityClassName: {{ .Values.threatdetection.podPriorityClassName }}
  {{- end }}
  {{- with .Values.threatdetection.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.threatdetection.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.threatdetection.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.threatdetection.imagePullSecrets }}
  imagePullSecrets: 
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if eq .Values.threatdetection.driver.kind "gvisor" }}
  hostNetwork: true
  hostPID: true
  dnsPolicy: ClusterFirstWithHostNet
  {{- end }}
  containers:
    - name: {{ .Chart.Name }}
      image: {{ include "threat-detection.image" . }}
      imagePullPolicy: {{ .Values.threatdetection.image.pullPolicy }}
      resources:
        {{- toYaml .Values.threatdetection.resources | nindent 8 }}
      securityContext:
        {{- include "threat-detection.securityContext" . | nindent 8 }}
      args:
        - /usr/bin/falco
        {{- include "threat-detection.configSyscallSource" . | indent 8 }}
    {{- with .Values.threatdetection.extra.args }}
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
      {{- if .Values.threatdetection.extra.env }}
      {{- include "kubernetes-agent.renderTemplate" ( dict "value" .Values.threatdetection.extra.env "context" $) | nindent 8 }}
      {{- end }}
      tty: {{ .Values.threatdetection.tty }}
      {{- if .Values.threatdetection.falco.webserver.enabled }}
      ports:
        - containerPort: {{ .Values.threatdetection.falco.webserver.listen_port }}
          name: web
          protocol: TCP
      livenessProbe:
        initialDelaySeconds: {{ .Values.threatdetection.healthChecks.livenessProbe.initialDelaySeconds }}
        timeoutSeconds: {{ .Values.threatdetection.healthChecks.livenessProbe.timeoutSeconds }}
        periodSeconds: {{ .Values.threatdetection.healthChecks.livenessProbe.periodSeconds }}
        failureThreshold: 45
        httpGet:
          path: {{ .Values.threatdetection.falco.webserver.k8s_healthz_endpoint }}
          port: {{ .Values.threatdetection.falco.webserver.listen_port }}
          {{- if .Values.threatdetection.falco.webserver.ssl_enabled }}
          scheme: HTTPS
          {{- end }}
      readinessProbe:
        initialDelaySeconds: {{ .Values.threatdetection.healthChecks.readinessProbe.initialDelaySeconds }}
        timeoutSeconds: {{ .Values.threatdetection.healthChecks.readinessProbe.timeoutSeconds }}
        periodSeconds: {{ .Values.threatdetection.healthChecks.readinessProbe.periodSeconds }}
        httpGet:
          path: {{ .Values.threatdetection.falco.webserver.k8s_healthz_endpoint }}
          port: {{ .Values.threatdetection.falco.webserver.listen_port }}
          {{- if .Values.threatdetection.falco.webserver.ssl_enabled }}
          scheme: HTTPS
          {{- end }}
      {{- end }}
      volumeMounts:
      {{- include "threat-detection.containerPluginVolumeMounts" . | nindent 8 -}}
      {{- if or .Values.threatdetection.falcoctl.artifact.install.enabled .Values.threatdetection.falcoctl.artifact.follow.enabled }}
      {{- if has "rulesfile" .Values.threatdetection.falcoctl.config.artifact.allowedTypes }}
        - mountPath: /etc/falco
          name: rulesfiles-install-dir
      {{- end }}
      {{- if has "plugin" .Values.threatdetection.falcoctl.config.artifact.allowedTypes }}
        - mountPath: /usr/share/falco/plugins
          name: plugins-install-dir
      {{- end }}
      {{- end }}
      {{- if eq (include "threat-detection.driverLoader.enabled" .) "true" }}
        - mountPath: /etc/falco/config.d
          name: specialized-falco-configs
      {{- end }}
        - mountPath: /root/.falco
          name: root-falco-fs
        - mountPath: /host/proc
          name: proc-fs
        {{- if and .Values.threatdetection.driver.enabled (not .Values.threatdetection.driver.loader.enabled) }}
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
        {{- if .Values.threatdetection.driver.enabled }}
        - mountPath: /host/etc
          name: etc-fs
          readOnly: true
        {{- end -}}
        {{- if and .Values.threatdetection.driver.enabled (or (eq .Values.threatdetection.driver.kind "kmod") (eq .Values.threatdetection.driver.kind "module") (eq .Values.threatdetection.driver.kind "auto")) }}
        - mountPath: /host/dev
          name: dev-fs
          readOnly: true
        - name: sys-fs
          mountPath: /sys/module
        {{- end }}
        {{- if and .Values.threatdetection.driver.enabled (and (eq .Values.threatdetection.driver.kind "ebpf") (contains "falco-no-driver" .Values.threatdetection.image.repository)) }}
        - name: debugfs
          mountPath: /sys/kernel/debug
        {{- end }}
        - mountPath: /etc/falco/falco.yaml
          name: falco-yaml
          subPath: falco.yaml
        - mountPath: /etc/falco/aikido-rules.d
          name: aikido-rules-volume
        {{- if eq .Values.threatdetection.driver.kind "gvisor" }}
        - mountPath: /usr/local/bin/runsc
          name: runsc-path
          readOnly: true
        - mountPath: /host{{ .Values.threatdetection.driver.gvisor.runsc.root }}
          name: runsc-root
        - mountPath: /host{{ .Values.threatdetection.driver.gvisor.runsc.config }}
          name: runsc-config
        - mountPath: /gvisor-config
          name: falco-gvisor-config
        {{- end }}
  {{- if .Values.threatdetection.falcoctl.artifact.follow.enabled }}
    {{- include "falcoctl.sidecar" . | nindent 4 }}
  {{- end }}
  initContainers:
  {{- with .Values.threatdetection.extra.initContainers }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if eq .Values.threatdetection.driver.kind "gvisor" }}
  {{- include "threat-detection.gvisor.initContainer" . | nindent 4 }}
  {{- end }}
  {{- if eq (include "threat-detection.driverLoader.enabled" .) "true" }}
    {{- include "threat-detection.driverLoader.initContainer" . | nindent 4 }}
  {{- end }}
  {{- if .Values.threatdetection.falcoctl.artifact.install.enabled }}
    {{- include "falcoctl.initContainer" . | nindent 4 }}
  {{- end }}
  volumes:
    {{- include "threat-detection.containerPluginVolumes" . | nindent 4 -}}
    {{- if eq (include "threat-detection.driverLoader.enabled" .) "true" }}
    - name: specialized-falco-configs
      emptyDir: {}
    {{- end }}
    {{- if or .Values.threatdetection.falcoctl.artifact.install.enabled .Values.threatdetection.falcoctl.artifact.follow.enabled }}
    - name: plugins-install-dir
      emptyDir: {}
    - name: rulesfiles-install-dir
      emptyDir: {}
    {{- end }}
    - name: root-falco-fs
      emptyDir: {}
    {{- if .Values.threatdetection.driver.enabled }}  
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
    {{- if and .Values.threatdetection.driver.enabled (or (eq .Values.threatdetection.driver.kind "kmod") (eq .Values.threatdetection.driver.kind "module") (eq .Values.threatdetection.driver.kind "auto")) }}
    - name: dev-fs
      hostPath:
        path: /dev
    - name: sys-fs
      hostPath:
        path: /sys/module
    {{- end }}
    {{- if and .Values.threatdetection.driver.enabled (and (eq .Values.threatdetection.driver.kind "ebpf") (contains "falco-no-driver" .Values.threatdetection.image.repository)) }}
    - name: debugfs
      hostPath:
        path: /sys/kernel/debug
    {{- end }}
    - name: proc-fs
      hostPath:
        path: /proc
    {{- if eq .Values.threatdetection.driver.kind "gvisor" }}
    - name: runsc-path
      hostPath:
        path: {{ .Values.threatdetection.driver.gvisor.runsc.path }}/runsc
        type: File
    - name: runsc-root
      hostPath:
        path: {{ .Values.threatdetection.driver.gvisor.runsc.root }}
    - name: runsc-config
      hostPath:
        path: {{ .Values.threatdetection.driver.gvisor.runsc.config }}
        type: File
    - name: falco-gvisor-config
      emptyDir: {}
    {{- end }}
    - name: falcoctl-config-volume
      configMap: 
        name: {{ include "threat-detection.name" . }}-falcoctl
        items:
          - key: falcoctl.yaml
            path: falcoctl.yaml
    - name: falco-yaml
      configMap:
        name: {{ include "threat-detection.name" . }}
        items:
        - key: falco.yaml
          path: falco.yaml
    - name: aikido-rules-volume
      configMap:
        name: {{ include "threat-detection.name" . }}-custom-rules
    {{- end -}}

{{- define "threat-detection.driverLoader.initContainer" -}}
- name: {{ .Chart.Name }}-driver-loader
  image: {{ include "threat-detection.driverLoader.image" . }}
  imagePullPolicy: {{ .Values.threatdetection.driver.loader.initContainer.image.pullPolicy }}
  args:
  {{- with .Values.threatdetection.driver.loader.initContainer.args }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if eq .Values.threatdetection.driver.kind "module" }}
    - kmod
  {{- else if eq .Values.threatdetection.driver.kind "modern-bpf"}}
    - modern_ebpf
  {{- else }}
    - {{ .Values.threatdetection.driver.kind }}
  {{- end }}
  {{- with .Values.threatdetection.driver.loader.initContainer.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  securityContext:
  {{- if .Values.threatdetection.driver.loader.initContainer.securityContext }}
    {{- toYaml .Values.threatdetection.driver.loader.initContainer.securityContext | nindent 4 }}
  {{- else if (or (eq .Values.threatdetection.driver.kind "kmod") (eq .Values.threatdetection.driver.kind "module") (eq .Values.threatdetection.driver.kind "auto")) }}
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
  {{- if .Values.threatdetection.driver.loader.initContainer.env }}
  {{- include "kubernetes-agent.renderTemplate" ( dict "value" .Values.threatdetection.driver.loader.initContainer.env "context" $) | nindent 4 }}
  {{- end }}
  {{- if eq .Values.threatdetection.driver.kind "auto" }}
    - name: FALCOCTL_DRIVER_CONFIG_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: FALCOCTL_DRIVER_CONFIG_CONFIGMAP
      value: {{ include "threat-detection.name" . }}
  {{- else }}
    - name: FALCOCTL_DRIVER_CONFIG_UPDATE_FALCO
      value: "false"
  {{- end }}
{{- end -}}

{{- define "threat-detection.securityContext" -}}
{{- $securityContext := dict -}}
{{- if .Values.threatdetection.driver.enabled -}}
  {{- if (or (eq .Values.threatdetection.driver.kind "kmod") (eq .Values.threatdetection.driver.kind "module") (eq .Values.threatdetection.driver.kind "auto")) -}}
    {{- $securityContext := set $securityContext "privileged" true -}}
  {{- end -}}
  {{- if eq .Values.threatdetection.driver.kind "ebpf" -}}
    {{- if .Values.threatdetection.driver.ebpf.leastPrivileged -}}
      {{- $securityContext := set $securityContext "capabilities" (dict "add" (list "SYS_ADMIN" "SYS_RESOURCE" "SYS_PTRACE")) -}}
    {{- else -}}
      {{- $securityContext := set $securityContext "privileged" true -}}
    {{- end -}}
  {{- end -}}
  {{- if (or (eq .Values.threatdetection.driver.kind "modern_ebpf") (eq .Values.threatdetection.driver.kind "modern-bpf")) -}}
    {{- if .Values.threatdetection.driver.modernEbpf.leastPrivileged -}}
      {{- $securityContext := set $securityContext "capabilities" (dict "add" (list "BPF" "SYS_RESOURCE" "PERFMON" "SYS_PTRACE")) -}}
    {{- else -}}
      {{- $securityContext := set $securityContext "privileged" true -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if not (empty (.Values.threatdetection.containerSecurityContext)) -}}
  {{-  toYaml .Values.threatdetection.containerSecurityContext }}
{{- else -}}
  {{- toYaml $securityContext }}
{{- end -}}
{{- end -}}
