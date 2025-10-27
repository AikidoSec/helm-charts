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

#### Installation

```bash
# Basic installation
helm install aikido-agent ./kubernetes-agent --set config.apiToken=your-token

# Installation with proxy support
helm install aikido-agent ./kubernetes-agent -f values-proxy-example.yaml
```
