# Fusion Electronics MERN App

Project nay la ung dung e-commerce MERN gom React frontend, Express backend va MongoDB. Repo da duoc don gon de tap trung cho muc tieu tiep theo: dong goi thanh Helm chart va deploy len Kubernetes.

## Runtime Mapping

| Layer | Path | Vai tro |
| --- | --- | --- |
| Frontend | `src/`, `public/`, `Dockerfile` | React SPA build bang CRACO, serve bang nginx trong container |
| Backend | `backend/`, `backend/Dockerfile` | Express API, MongoDB/Mongoose, auth, checkout, products, search, Swagger |
| Database | MongoDB | Duoc cau hinh qua `MONGO_URI` |
| K8s reference | `deployment/k8s/` | Manifest tham khao de chuyen thanh Helm templates |
| Local compose | `docker-compose.yml` | Chay nhanh frontend, backend va MongoDB tren may local |

## Main Commands

```bash
npm install
cd backend && npm install
```

```bash
npm run dev
```

```bash
npm test
cd backend && npm test
```

```bash
docker compose up --build
```

## Environment

Backend can cac bien moi truong chinh:

```env
MONGO_URI=mongodb://mongodb:27017/Ecommerce-Products
JWT_SECRET=change-me
PORT=8000
SKIP_SEED_ON_START=false
PINECONE_API_KEY=
PINECONE_HOST=
PINECONE_INDEX=
PINECONE_NAMESPACE=ecommerce-products
GOOGLE_AI_API_KEY=
```

Pinecone/Google AI co the de trong khi test luong co ban; backend co fallback cho recommendation khi vector sync loi.

## Helm Preparation Notes

Nhung thanh phan nen dua vao chart:

- Helm chart hoan chinh nam tai `charts/fusion-electronics/`.
- `frontend` Deployment, Service va Ingress route cho SPA.
- `backend` Deployment, Service, ConfigMap va Secret.
- MongoDB dung Bitnami MongoDB dependency mac dinh cho dev/test.
- `deployment/k8s/` chi con vai tro manifest tham khao.
- Chi tiet mapping nam trong `deployment/HELM_PREP.md`.

## GitHub Actions Deploy

Workflow `.github/workflows/ci.yml` se:

- Chay frontend build va frontend/backend tests tren pull request.
- Build va push image frontend/backend len GHCR khi push `main`, `master`, hoac chay manual.
- Deploy bang Helm neu secret `KUBE_CONFIG_DATA` da duoc cau hinh.

GitHub Secrets can thiet:

- `KUBE_CONFIG_DATA`: kubeconfig base64.
- `JWT_SECRET`: JWT signing secret cho backend.

Optional:

- `PINECONE_API_KEY`
- `PINECONE_HOST`
- `PINECONE_INDEX`
- `GOOGLE_AI_API_KEY`
- `WEAVIATE_HOST`
- `WEAVIATE_API_KEY`

Nhung thu da bo khoi repo:

- React Buddy IDE preview tooling.
- Anh screenshot/tai lieu marketing khong can cho runtime.
- Script publish ca nhan, Vercel backend config.
- Manifest Kubernetes trung lap va canary/blue-green shell flow thu cong.
- FAISS index da build san; neu can co the generate lai bang script trong `backend/scripts/`.
