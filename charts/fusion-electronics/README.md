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
  --create-namespace
```

Add this host entry for a local ingress test:

```text
<INGRESS_IP> fusion-electronics.local
```

## Override For Your Lab

Edit `values.yaml` directly for a VMware lab, or pass overrides at deploy time:

```bash
helm upgrade --install fusion-electronics charts/fusion-electronics \
  --namespace fusion-ecommerce \
  --create-namespace \
  --set frontend.image.repository=ghcr.io/YOUR_ORG/mern-ecom-frontend \
  --set backend.image.repository=ghcr.io/YOUR_ORG/mern-ecom-backend
```

## GitHub Actions Secrets

Required:

- `KUBE_CONFIG_DATA`: base64 encoded kubeconfig
- `JWT_SECRET`: backend JWT signing secret

Optional:

- `PINECONE_API_KEY`
- `PINECONE_HOST`
- `PINECONE_INDEX`
- `WEAVIATE_HOST`
- `WEAVIATE_API_KEY`

`MONGO_URI` is generated automatically for the MongoDB service created by this chart, for example:

```text
mongodb://fusion-electronics-mongodb:27017/Ecommerce-Products
```

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
