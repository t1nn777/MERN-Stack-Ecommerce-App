# Fluent Bit for Fusion Electronics Logs

This deploys Fluent Bit as a DaemonSet and ships only Fusion Electronics application logs to Elasticsearch.

It collects:

- namespace: `fusion-ecommerce`
- pods matching: `fusion-electronics-backend-*`, `fusion-electronics-frontend-*`, and `attack-log-generator`
- source files: `/var/log/containers/*.log`
- Elasticsearch index prefix: `k8s-logs-mern-*`

## Configure Elasticsearch

Edit `daemonset.yaml` if your Elasticsearch VM IP is different:

```yaml
env:
  - name: FLUENT_ELASTICSEARCH_HOST
    value: "172.16.30.250"
  - name: FLUENT_ELASTICSEARCH_PORT
    value: "9200"
```

## Apply

```bash
kubectl apply -k deployment/efk/fluent-bit
```

## Verify

```bash
kubectl get pods -n logging -o wide
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=100
curl http://172.16.30.250:9200/_cat/indices/k8s-logs-mern-*?v
```

If you are testing with `attack-log-generator`, recreate the pod after applying this
configuration. Fluent Bit may already have tailed and checkpointed the old pod log
while the previous grep filter dropped it.

In Kibana, create a Data View:

```text
k8s-logs-mern-*
```

Then search for application access logs:

```text
type: "http_access"
```
