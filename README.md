# helm-charts

These helm charts will help Aikido customers install Kubernetes monitoring

## Kubernetes Agent

The `kubernetes-agent` chart deploys the Aikido Kubernetes security monitoring agent.

### Configuration

#### Basic Configuration

```yaml
config:
  apiToken: 'your-api-token'
  apiEndpoint: 'https://k8s.aikido-security.com'
```

#### HTTP Proxy Support

If your cluster requires HTTP proxy for outbound connections:

```yaml
config:
  proxy:
    httpProxy: 'http://proxy.company.com:8080'
    httpsProxy: 'http://proxy.company.com:8080'
    noProxy: 'localhost,127.0.0.1,.local,.cluster.local'
```

### Installation

```bash
# Basic installation
helm install aikido-agent ./kubernetes-agent --set config.apiToken=your-token

# Installation with proxy support
helm install aikido-agent ./kubernetes-agent -f values-proxy-example.yaml
```

### Using an External Secret

By default, the Helm chart creates a Kubernetes Secret containing the agent configuration. However, you can also use your own externally managed secret.

To use an external secret, set the following value:
```yaml
agent:
  externalSecret: "my-custom-secret-name"
```

When externalSecret is set:
- The chart will not create a Secret resource
- The specified secret name will be used for the agent configuration
- RBAC permissions will be granted to access the external secret

#### External Secret Requirements

Your external secret must:
1. Be created in the same namespace as the Helm release
2. Contain a config.yaml key with the following structure, as shown below (this must match what the agent expects):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-custom-secret-name
  namespace: aikido
type: Opaque
stringData:
  config.yaml: |
    apiEndpoint: "https://k8s.aikido-security.com"
    apiToken: "your-api-token-here"
```

### In-cluster image scanning

Aikido scans container images directly within your Kubernetes cluster and generates Software Bills of Materials (SBOMs) that are analyzed by the platform for potential issues.

The chart always deploys the SBOM collector components (DaemonSet or Deployment) by default. These components remain dormant until activated through the Aikido platform. This allows the scanning feature to be enabled without requiring a Helm chart upgrade.
