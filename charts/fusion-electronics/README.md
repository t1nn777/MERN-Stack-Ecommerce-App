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

## Observability: Fluent Bit + MS Teams Alerts

The chart can also deploy Fluent Bit and a MS Teams alert CronJob. These are
disabled by default so normal app installs do not fail when Elasticsearch,
Teams, or the Elasticsearch CA Secret are not ready.

Create the Elasticsearch CA Secret in the observability namespace first:

```bash
kubectl create namespace logging
kubectl create secret generic elasticsearch-ca \
  -n logging \
  --from-file=ca.crt=./http_ca.crt
```

Install or upgrade with observability enabled:

```bash
helm upgrade --install fusion-electronics charts/fusion-electronics \
  --namespace fusion-ecommerce \
  --create-namespace \
  --set secrets.JWT_SECRET='your-jwt-secret' \
  --set observability.enabled=true \
  --set observability.elasticsearch.host=192.168.1.250 \
  --set observability.elasticsearch.username=elastic \
  --set observability.elasticsearch.password='your-elastic-password' \
  --set observability.teamsAlert.webhookUrl='https://your-teams-webhook'
```

The Teams alert poller checks recent Elasticsearch logs for reconnaissance,
brute-force login, search injection, NoSQL injection, product ID fuzzing,
checkout abuse, backend health failures, and missing readiness success logs.
It also uses the Kubernetes API to check pod readiness, restart counts,
container waiting errors, unavailable deployments, and warning events.

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
