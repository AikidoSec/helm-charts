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

### Custom CA Certificates

If your cluster uses a TLS-intercepting proxy, the agent container may not trust the proxy's CA certificate. You can mount a custom CA bundle using `additionalVolumes` and `additionalVolumeMounts`, and point Go's TLS stack at it with the `SSL_CERT_FILE` or `SSL_CERT_DIR` environment variable.

```yaml
additionalEnvVars:
  - name: SSL_CERT_FILE
    value: /etc/ssl/custom/ca-certificates.crt

additionalVolumes:
  - name: custom-ca
    hostPath:
      path: /etc/ssl/certs
      type: Directory

additionalVolumeMounts:
  - name: custom-ca
    mountPath: /etc/ssl/custom
    readOnly: true
```

The volume source can be a `hostPath`, `configMap`, `secret`, or any other Kubernetes volume type that contains your CA bundle.

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

### Private registry authentication

The SBOM collector supports multiple mechanisms for authenticating to private registries when it needs to fetch images for SBOM generation.

#### Read workload image pull secrets

The collector can read the same Kubernetes pull secrets used by workload pods.

Relevant Helm values:

```yaml
sbomCollector:
  secretsAccess:
    enabled: true
    imagePullSecretNames: []
```

How it works:

- The collector reads `imagePullSecrets` referenced by workload pods in their own namespace through the Kubernetes API.
- `sbomCollector.secretsAccess.imagePullSecretNames` limits which secret names the collector is allowed to read.
- If `imagePullSecretNames` is empty, the collector can read all secrets cluster-wide.

Notes:

- `sbomCollector.secretsAccess.imagePullSecretNames` contains secret names only, not `namespace/name` pairs. Since Kubernetes secrets are namespace-scoped, allowing a name such as `regcred` allows access to secrets with that name in any namespace.

#### Use pull secrets attached to the SBOM collector service account

The collector can also use pull secrets attached to its own service account.

Relevant Helm values:

```yaml
sbomCollector:
  secretsAccess:
    enabled: true
    imagePullSecretNames: []
  serviceAccount:
    create: true
    name: ''
    imagePullSecrets: []
```

How it works:

- The collector reads the pull secret names attached to its own service account.
- It then resolves those secrets through the Kubernetes API when building the registry keychain.

Notes:

- This option still requires `sbomCollector.secretsAccess.enabled: true`.
- If `sbomCollector.secretsAccess.imagePullSecretNames` is non-empty, it must include the secret names attached to the SBOM collector service account.
- If you use this option together with a scoped `imagePullSecretNames` list, prefer a secret name unique to Aikido to avoid unintentionally granting access to unrelated secrets with the same name in other namespaces.
- This option can reduce scope compared to workload-wide secret access, but it does not avoid secret-read RBAC entirely.

#### Mount a Docker config secret directly into the collector

The collector supports mounting a Docker config secret as a volume.

Relevant Helm values:

```yaml
sbomCollector:
  pullSecretMount:
    secretName: ''
```

How it works:

- The named secret is mounted directly into the SBOM collector pod.
- Supported secret formats:
  - `kubernetes.io/dockerconfigjson`
  - `kubernetes.io/dockercfg`

Notes:

- The mounted secret must exist in the same namespace as the chart release.
- This is useful when you want to provide a dedicated Docker config directly to the collector. Especially relevant for OpenShift clusters.

#### Choosing a mechanism

1. If the registry supports environment-based cloud auth (e.g., EKS Pod Identity), ensure the collector has the required identity and permissions. See the sections below.
1. If the registry does not support cloud auth, `sbomCollector.secretsAccess` is the simplest option. Use this if granting RBAC read access to workload pull secrets is acceptable for you.
1. If you want the collector to use its own pull secret instead of workload pull secrets, use `sbomCollector.serviceAccount.imagePullSecrets` together with `sbomCollector.secretsAccess.enabled=true`. If you scope `sbomCollector.secretsAccess.imagePullSecretNames`, include the collector service account pull secret names there as well.
1. If granting secret-read RBAC is not an option, use `sbomCollector.pullSecretMount.secretName`.

### AWS EKS Pod Identity

For EKS Pod Identity, you need to create a pod identity association for the SBOM collector service account, `aikido-kubernetes-agent-sbom-collector`, namespace `aikido` if using the default values. Read more in the [AWS docs](https://docs.aws.amazon.com/eks/latest/userguide/pod-id-association.html).

1. Ensure the **EKS Pod Identity Agent** add-on is installed:

```bash
aws eks create-addon --cluster-name <cluster> --addon-name eks-pod-identity-agent
```

2. Create an IAM role with the following trust policy (the standard trust policy used when you create via the AWS Console), then attach `AmazonEC2ContainerRegistryReadOnly`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "pods.eks.amazonaws.com" },
      "Action": ["sts:AssumeRole", "sts:TagSession"]
    }
  ]
}
```

```bash
aws iam create-role --role-name aikido-sbom-collector-ecr --assume-role-policy-document file://trust-policy.json
aws iam attach-role-policy --role-name aikido-sbom-collector-ecr --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
```

3. Create the pod identity association (replace `<cluster>`, `<namespace>`, `<release-name>`, and `<account-id>`):

```bash
aws eks create-pod-identity-association \
  --cluster-name <cluster> \
  --namespace <namespace> \
  --service-account <release-name>-sbom-collector \
  --role-arn arn:aws:iam::<account-id>:role/aikido-sbom-collector-ecr
```

No Helm values changes are needed — credentials are injected automatically at runtime. If the SBOM collector was already running before the association was created, restart it to pick up the credentials:

```bash
# DaemonSet (default)
kubectl rollout restart daemonset/<release-name>-sbom-collector -n <namespace>
# Deployment (if runAsDaemonSet: false)
kubectl rollout restart deployment/<release-name>-sbom-collector -n <namespace>
```

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

You can use the following command to create a policy binding, replacing `PROJECT_ID` and `PROJECT_NUMBER` with your values:

```bash
gcloud projects add-iam-policy-binding projects/PROJECT_ID \
  --role=roles/artifactregistry.reader \
  --member=principal://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/subject/ns/aikido/sa/aikido-kubernetes-agent-sbom-collector \
  --condition=None
```

## Using ExternalSecrets with the Chart

If you use a secret management solution like HashiCorp Vault or AWS Secrets Manager with the [ExternalSecrets Operator](https://external-secrets.io/), you can use the `extraObjects` field to deploy an ExternalSecret resource alongside the chart. This eliminates the need for a separate Helm release or manifest application.

### Example Configuration

```yaml
agent:
  externalSecret: 'aikido-credentials'

extraObjects:
  - |
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: {{ .Values.agent.externalSecret }}
      namespace: {{ .Release.Namespace }}
    spec:
      refreshInterval: 1h
      secretStoreRef:
        kind: ClusterSecretStore
        name: vault
      target:
        name: {{ .Values.agent.externalSecret }}
        creationPolicy: Owner
      data:
        - secretKey: config.yaml
          remoteRef:
            key: secrets/aikido/config
            property: config.yaml
```

**Note:** The ExternalSecret should create a secret with a `config.yaml` key containing the agent configuration in YAML format with `apiEndpoint` and `apiToken` fields, as shown in the [External Secret Requirements](#external-secret-requirements) section above.
