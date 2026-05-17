# Helm Preparation Map

## Application Components

| Component | Source | Image source | Runtime port | Kubernetes reference |
| --- | --- | --- | --- | --- |
| Frontend | `src/`, `public/` | root `Dockerfile` | `80` | `deployment/k8s/frontend-*.yaml` |
| Backend API | `backend/` | `backend/Dockerfile` | `8000` | `deployment/k8s/backend-*.yaml` |
| MongoDB | chart dependency | Bitnami MongoDB | `27017` | backend uses generated in-cluster service URI |

## Helm Chart Shape

Implemented chart layout:

```text
charts/fusion-electronics/
  Chart.yaml
  values.yaml
  README.md
  templates/
    namespace.yaml
    configmap.yaml
    secret.yaml
    frontend-deployment.yaml
    frontend-service.yaml
    backend-deployment.yaml
    backend-service.yaml
    ingress.yaml
    hpa.yaml
    pdb.yaml
    network-policy.yaml
```

## Values Parameterized

- `namespace`
- `frontend.image.repository`, `frontend.image.tag`, `frontend.replicaCount`
- `backend.image.repository`, `backend.image.tag`, `backend.replicaCount`
- `backend.env.PORT`, `backend.env.NODE_ENV`, `backend.env.SKIP_SEED_ON_START`
- `secrets.JWT_SECRET`, `secrets.PINECONE_API_KEY`
- `ingress.enabled`, `ingress.className`, `ingress.hosts`, `ingress.tls`
- `autoscaling.enabled`, min/max replicas, CPU/memory targets
- `networkPolicy.enabled`

## GitHub Actions

`.github/workflows/ci.yml` validates the chart, builds both images, pushes them to GHCR, and deploys with Helm when `KUBE_CONFIG_DATA` is configured.

## Cleanup Decisions

- Kept one Kubernetes reference folder: `deployment/k8s/`.
- Removed duplicate basic manifests from `kubernetes/` after folding Deployment/Service references into `deployment/k8s/`.
- Removed manual blue-green/canary shell flows because Helm can model release/rollback cleanly.
- Removed generated FAISS index files; keep scripts only, regenerate when needed.
- Removed frontend IDE preview tooling and unused frontend dependencies.
