# Security and Health Alerting

## MS Teams Alert Poller

`teams-alert-poller.sh` sends Fusion Electronics security and health alerts to a Microsoft Teams Incoming Webhook. It is standalone and independent from the Jira alert poller.

The poller checks:

- Security log patterns: recon, brute-force-login, search-injection, nosql-injection, product-id-fuzzing, and checkout-abuse.
- Backend health logs: `/health` 5xx, `/health/ready` failures, and missing `/health/ready` success logs in the lookback window.
- Kubernetes health: pods not Ready, restart count threshold, CrashLoopBackOff/ImagePullBackOff/ErrImagePull waiting states, unavailable deployment replicas, and warning events for Fusion backend/frontend pods.

Required tools for local runs:

- `curl`
- `jq`
- `kubectl`, for Kubernetes health checks. If it is not installed, only Kubernetes checks are skipped.

Default Elasticsearch settings:

- `ES_URL=https://192.168.1.250:9200`
- `ES_INDEX_PATTERN=k8s-logs-mern-*`
- `ES_USER=elastic`
- `ES_PASSWORD` is optional.
- `ES_CA_CERT` is optional and is passed to curl with `--cacert` when set.

Example local dry run:

```bash
TEAMS_DRY_RUN=true \
ES_URL=https://192.168.1.250:9200 \
ES_USER=elastic \
ES_PASSWORD='your-elastic-password' \
ES_CA_CERT=./http_ca.crt \
./deployment/security/teams-alert-poller.sh
```

Example live run:

```bash
TEAMS_WEBHOOK_URL='https://...' \
ES_URL=https://192.168.1.250:9200 \
ES_USER=elastic \
ES_PASSWORD='your-elastic-password' \
ES_CA_CERT=./http_ca.crt \
KIBANA_URL=https://192.168.1.250:5601 \
./deployment/security/teams-alert-poller.sh
```

To generate test logs from an authorized staging or lab API:

```bash
API=https://your-api-host ./deployment/security/attack-sim.sh light --confirm-authorized
API=https://your-api-host ./deployment/security/injection-sim.sh nosql --confirm-authorized
```

To verify backend health logs:

```bash
curl https://your-api-host/health
curl https://your-api-host/health/ready
```

## Optional In-Cluster CronJob

`teams-alert-cronjob.yaml` is an optional in-cluster schedule. It creates:

- A `teams-alert-poller` ServiceAccount in the `logging` namespace.
- A Role and RoleBinding in the `fusion-ecommerce` namespace for pods, events, and deployments.
- A Secret template with placeholder Teams webhook and Elasticsearch password values.
- A ConfigMap placeholder for the script.
- A CronJob in the `logging` namespace.

Before applying, replace the Secret placeholders and generate the script ConfigMap from the checked-in script:

```bash
kubectl create secret generic elasticsearch-ca \
  -n logging \
  --from-file=ca.crt=./http_ca.crt

kubectl create configmap teams-alert-poller \
  -n logging \
  --from-file=teams-alert-poller.sh=deployment/security/teams-alert-poller.sh \
  --dry-run=client -o yaml
```

Use that output to replace the placeholder ConfigMap section in `deployment/security/teams-alert-cronjob.yaml`, then validate:

```bash
kubectl apply --dry-run=client -f deployment/security/teams-alert-cronjob.yaml
```
