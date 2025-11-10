# helm-charts

Helm charts for deploying the Aikido Kubernetes security monitoring agent.

## Configuration

### Basic Configuration

```yaml
config:
  apiToken: 'your-api-token'
  apiEndpoint: 'https://k8s.aikido-security.com'
```

### HTTP Proxy Support

If your cluster requires HTTP proxy for outbound connections:

```yaml
config:
  proxy:
    httpProxy: 'http://proxy.company.com:8080'
    httpsProxy: 'http://proxy.company.com:8080'
    noProxy: 'localhost,127.0.0.1,.local,.cluster.local'
```

## Installation

```bash
# Basic installation
helm install aikido-agent ./kubernetes-agent --set config.apiToken=your-token
```

## Using an External Secret

By default, the Helm chart creates a Kubernetes Secret containing the agent configuration. However, you can also use your own externally managed secret.

To use an external secret, set the following value:

```yaml
agent:
  externalSecret: 'my-custom-secret-name'
```

When externalSecret is set:

- The chart will not create a Secret resource
- The specified secret name will be used for the agent configuration
- RBAC permissions will be granted to access the external secret

### External Secret Requirements

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

## In-cluster image scanning

Aikido can generate SBOMs (Software Bill of Materials) for container images deployed in your Kubernetes cluster. This is done by a separate component, the SBOM collector, which can run as a DaemonSet, leveraging the image cache from each node, or a Deployment.

For pulling, the collector attempts first to pull the images from the nodes' cache, through the containerd/docker sockets. If the image is not found in the cache, it will attempt to pull it from the registry. For private registries, the collector requires access to the same image pull secrets that pods use.

For environments running on managed Kubernetes services, Aikido supports authentication via native workload identities.

### AWS EKS Pod Identity

For EKS Pod Identity, you need to create a pod identity association for the SBOM collector service account, `aikido-kubernetes-agent-sbom-collector`, namespace `aikido` if using the default values. Read more in the [AWS docs](https://docs.aws.amazon.com/eks/latest/userguide/pod-id-association.html).

### Azure Workload Identity

For Azure Workload Identity, follow the [Azure docs](https://learn.microsoft.com/en-us/azure/aks/workload-identity-deploy-cluster).

Set the user assigned identity on the service account and the pod label:

```yaml
sbomCollector:
  serviceAccount:
    annotations:
      azure.workload.identity/client-id: '12345678-1234-1234-1234-123456789012'
  podLabels:
    azure.workload.identity/use: 'true'
```

### GKE Workload Identity

For GKE Workload Identity, you can add a policy binding directly for the SBOM collector service account. The default values use the `aikido-kubernetes-agent-sbom-collector` service account and namespace `aikido`. Read more in the [GCP docs](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/workload-identity).
