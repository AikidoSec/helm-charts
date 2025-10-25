# GitOps-Friendly Secret Management

This document outlines several approaches for securely managing the Aikido API token in GitOps environments.

## Approach 1: External Secret Reference (Recommended)

Reference an existing Kubernetes secret instead of embedding the token in your values:

```yaml
config:
  existingSecret:
    name: 'aikido-api-secret'
    key: 'token'
```

**Setup:**

1. Create the secret manually or via your secret management tool:

   ```bash
   kubectl create secret generic aikido-api-secret \
     --from-literal=token="your-api-token-here"
   ```

2. Deploy with the chart:
   ```bash
   helm install aikido-agent ./kubernetes-agent \
     --set config.existingSecret.name=aikido-api-secret
   ```

## Approach 2: External Secrets Operator

Use the [External Secrets Operator](https://external-secrets.io/) to sync from external secret stores:

```yaml
# external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: aikido-api-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: aikido-api-secret
    creationPolicy: Owner
  data:
    - secretKey: token
      remoteRef:
        key: aikido/k8s-agent
        property: apiToken
```

## Approach 3: Sealed Secrets

Use [Sealed Secrets](https://sealed-secrets.netlify.app/) for encrypted secrets in Git:

```bash
# Create sealed secret
echo -n "your-api-token" | kubectl create secret generic aikido-api-secret \
  --dry-run=client --from-file=token=/dev/stdin -o yaml | \
  kubeseal -o yaml > aikido-sealed-secret.yaml
```

## Approach 4: Environment Variable Override

Set the token via environment variables in your deployment pipeline:

```yaml
# In your ArgoCD/Flux application
spec:
  source:
    helm:
      parameters:
        - name: config.apiToken
          value: $AIKIDO_API_TOKEN # Injected by CI/CD
```

## Security Best Practices

1. **Principle of Least Privilege**: Grant minimal RBAC permissions
2. **Secret Rotation**: Regularly rotate API tokens
3. **Audit Logging**: Monitor secret access
4. **Namespace Isolation**: Deploy in dedicated namespaces
5. **Network Policies**: Restrict network access where possible

## Compatibility Matrix

| Approach        | GitOps Friendly | Secret Rotation | Cloud Native | Complexity |
| --------------- | --------------- | --------------- | ------------ | ---------- |
| External Secret | ✅              | ✅              | ✅           | Low        |
| ESO             | ✅              | ✅              | ✅           | Medium     |
| Sealed Secrets  | ✅              | ⚠️              | ✅           | Medium     |
| Env Override    | ✅              | ⚠️              | ⚠️           | Low        |
