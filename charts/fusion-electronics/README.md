# Fusion Electronics Helm Chart

This chart deploys the Fusion Electronics MERN app with a React frontend, Express backend, and optional Bitnami MongoDB dependency.

## Prerequisites

- Kubernetes cluster with an ingress controller if `ingress.enabled=true`
- Helm 3
- Container images pushed to a registry such as GHCR

## Install Locally

```bash
helm dependency update charts/fusion-electronics
helm upgrade --install fusion-electronics charts/fusion-electronics \
  --namespace fusion-ecommerce \
  --create-namespace \
  -f charts/fusion-electronics/values-dev.yaml
```

Add this host entry for a local ingress test:

```text
<INGRESS_IP> fusion-electronics.local
```

## Production Override

Copy `values-prod.example.yaml`, replace image repositories, image tags, secrets, and ingress hosts, then deploy:

```bash
helm upgrade --install fusion-electronics charts/fusion-electronics \
  --namespace fusion-ecommerce \
  --create-namespace \
  -f my-prod-values.yaml
```

## GitHub Actions Secrets

Required:

- `KUBE_CONFIG_DATA`: base64 encoded kubeconfig
- `JWT_SECRET`: backend JWT signing secret

Optional:

- `PINECONE_API_KEY`
- `PINECONE_HOST`
- `PINECONE_INDEX`
- `GOOGLE_AI_API_KEY`
- `WEAVIATE_HOST`
- `WEAVIATE_API_KEY`

Create `KUBE_CONFIG_DATA` from a local kubeconfig:

```bash
base64 -w 0 ~/.kube/config
```

## Useful Checks

```bash
helm lint charts/fusion-electronics
helm template fusion-electronics charts/fusion-electronics --namespace fusion-ecommerce
kubectl get pods -n fusion-ecommerce
kubectl get ingress -n fusion-ecommerce
```
