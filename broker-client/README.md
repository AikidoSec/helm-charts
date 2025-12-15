# Aikido Broker Client Helm Chart

Deploy the Aikido Broker Client in your Kubernetes cluster to securely forward requests to internal resources.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- An Aikido Broker Client Secret (obtain from Aikido platform)

## Installation

### Quick Start

#### Add the Aikido Helm repository

```bash
helm repo add aikido https://aikidosec.github.io/helm-charts
helm repo update
```

```bash
helm install broker-client aikido/broker-client \
  --set config.clientSecret="AIK_BROKER_XXX_YYY_ZZZZ" \
  --namespace aikido \
  --create-namespace
```

### Using a values file

Create a `my-values.yaml`:

```yaml
config:
  clientSecret: 'AIK_BROKER_XXX_YYY_ZZZZ'
  allowedInternalSubnets: '10.0.0.0/8,172.16.0.0/12,192.168.0.0/16'

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 2000m
    memory: 1Gi

persistence:
  enabled: true
  size: 100Mi
```

Install:

```bash
helm install broker-client aikido/broker-client -f my-values.yaml --namespace aikido --create-namespace
```

## Configuration

### Required Parameters

| Parameter                       | Description                                               | Example                    |
| ------------------------------- | --------------------------------------------------------- | -------------------------- |
| `config.clientSecret`           | Your Aikido broker client secret                          | `AIK_BROKER_XXX_YYY_ZZZZ`  |
| `config.allowedInternalSubnets` | Comma-separated CIDR blocks for allowed internal networks | `10.0.0.0/8,172.16.0.0/12` |

### Optional Parameters

| Parameter                      | Description                                | Default                            |
| ------------------------------ | ------------------------------------------ | ---------------------------------- |
| `config.dnsServers`            | Custom DNS servers (comma-separated)       | `""`                               |
| `config.httpProxy`             | HTTP proxy for HTTP requests               | `""`                               |
| `config.httpsProxy`            | HTTPS proxy for HTTPS requests             | `""`                               |
| `config.allProxy`              | Universal proxy fallback for all protocols | `""`                               |
| `config.brokerTargetUrl`       | Custom broker target URL                   | `"https://broker.aikidobroker.com"`|
| `config.customCaBundleContent` | Custom CA certificate content (PEM format) | `""`                               |
| `config.nodeTlsRejectUnauthorized` | Disable TLS certificate validation (set to "0") | `""`                               |
| `image.repository`             | Docker image repository                    | `aikidosecurity/broker-client`     |
| `image.tag`                    | Docker image tag                           | Chart appVersion                   |
| `persistence.enabled`          | Enable persistent storage for client_id    | `true`                             |
| `persistence.size`             | PVC size                                   | `100Mi`                            |
| `resources.requests.cpu`       | CPU request                                | `100m`                             |
| `resources.requests.memory`    | Memory request                             | `256Mi`                            |
| `resources.limits.cpu`         | CPU limit                                  | `2000m` (2 vCPU)                   |
| `resources.limits.memory`      | Memory limit                               | `1Gi`                              |

### Example with Proxy and Custom CA

```yaml
config:
  clientSecret: 'AIK_BROKER_XXX_YYY_ZZZZ'
  allowedInternalSubnets: '10.0.0.0/8,172.16.0.0/12,192.168.0.0/16'
  httpsProxy: 'http://proxy.company.local:8080'
  customCaBundleContent: |
    -----BEGIN CERTIFICATE-----
    MIIDXTCCAkWgAwIBAgIJAKJ...
    -----END CERTIFICATE-----
```

## Accessing Internal Services

The broker client can access services within your Kubernetes cluster using:

- **Service DNS names**: `http://my-service.default.svc.cluster.local:8080`
- **Pod IPs**: `http://10.244.0.5:8080`
- **Service names** (same namespace): `http://my-service:8080`

Register these URLs as resources in the Aikido platform.

## Persistence

By default, the chart creates a PersistentVolumeClaim to store:

- `client_id` - Unique identifier for this broker client
- `client_resources.json` - Cached resource configurations

This ensures the client maintains its identity across pod restarts.

To disable persistence (not recommended for production):

```yaml
persistence:
  enabled: false
```

## Upgrading

```bash
helm upgrade broker-client ./helm/broker-client -f my-values.yaml
```

## Uninstalling

```bash
helm uninstall broker-client
```

Note: The PVC will not be automatically deleted. To remove it:

```bash
kubectl delete pvc broker-client
```

## Troubleshooting

### Check pod logs

```bash
kubectl logs -l app.kubernetes.io/name=broker-client -f
```

### Check pod status

```bash
kubectl get pods -l app.kubernetes.io/name=broker-client
```

### Verify configuration

```bash
kubectl get secret broker-client -o yaml
```

### Common Issues

1. **Connection refused to internal service**

   - Verify the service URL is correct (use `kubectl get svc` to check)
   - Ensure the service is in the same cluster
   - Check network policies aren't blocking traffic

2. **Authentication failed**

   - Verify `config.clientSecret` is correct
   - Check the secret exists: `kubectl get secret broker-client`

3. **Resource not allowed**

   - Register the resource URL in the Aikido platform
   - Wait for resource sync (happens every 3 minutes)

4. **Custom CA certificate issues**
   - Ensure certificate content is provided in PEM format in `config.customCaBundleContent`
   - Verify the certificate is valid and properly formatted
   - Example:
     ```yaml
     config:
       customCaBundleContent: |
         -----BEGIN CERTIFICATE-----
         MIIDXTCCAkWgAwIBAgIJAKJ...
         -----END CERTIFICATE-----
     ```

## Security Considerations

- The broker client runs as non-root user (UID 1000)
- All capabilities are dropped
- Read-only root filesystem (except /config for persistence)
- Client secret is stored as a Kubernetes Secret

## Support

For issues or questions:

- GitHub: https://github.com/AikidoSec/broker
- Documentation: https://help.aikido.dev
