# Observability

Monitoring stack combining Azure Monitor (cloud-native) and Prometheus/Grafana (Kubernetes-native).

## Architecture
```
AKS Cluster
├── ama-logs DaemonSet → Log Analytics Workspace
└── Prometheus Stack (monitoring namespace)
    ├── Prometheus (metrics)
    ├── Grafana (dashboards)
    ├── Alertmanager
    ├── Node Exporter (per node)
    └── kube-state-metrics
```

## Why Both?

**Azure Monitor**: Native Azure integration, long-term retention, KQL queries, cost tracking. Less flexible for custom dashboards.

**Prometheus + Grafana**: Kubernetes-native metrics, highly customizable dashboards, open-source. Requires cluster resources, shorter retention.

We use both — Azure Monitor for the cloud-wide view, Prometheus for application-specific metrics.

## Prometheus Stack

Deployed via Helm:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin123
```

Resource usage: ~500-700MB memory, ~0.3-0.5 CPU cores

Verify it's running:
```bash
kubectl get pods -n monitoring
```

## Grafana Access

Port-forward for local access:
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Open http://localhost:3000. Login: `admin` / `admin123`

For production, set up proper ingress with TLS and SSO.

### Dashboard: Kubernetes Pod Metrics (ID: 15760)

Import via: Dashboards → Import → Enter `15760` → Select Prometheus data source

Shows CPU/memory by container, network bandwidth, pod restarts, Kubernetes events.

## Prometheus Queries

Common queries:
```promql
# CPU usage by pod
sum(rate(container_cpu_usage_seconds_total{namespace="audiobookshelf"}[5m])) by (pod)

# Memory usage percentage
100 * container_memory_working_set_bytes{namespace="audiobookshelf"} 
/ container_spec_memory_limit_bytes{namespace="audiobookshelf"}

# Pod restart count
sum(kube_pod_container_status_restarts_total{namespace="audiobookshelf"}) by (pod)

# Network receive rate
rate(container_network_receive_bytes_total{namespace="audiobookshelf"}[5m])
```

## Azure Monitor (Container Insights)

Enabled via Terraform. Collects CPU, memory, disk, network, and container logs.

Verify the agent is running:
```bash
kubectl get pods -n kube-system -l app=ama-logs
```

### KQL Queries

Always check schema first:
```kusto
ContainerLog | take 1
```

Recent logs:
```kusto
ContainerLog
| where TimeGenerated > ago(1h)
| project TimeGenerated, Computer, LogEntry
| order by TimeGenerated desc
| take 50
```

Find errors:
```kusto
ContainerLog
| where TimeGenerated > ago(24h)
| where LogEntry contains "ERROR"
| project TimeGenerated, Computer, Name, LogEntry
| order by TimeGenerated desc
```

Pod restart alert query:
```kusto
KubePodInventory
| where TimeGenerated > ago(15m)
| summarize MaxRestarts = max(ContainerRestartCount) by Name, Namespace
| where MaxRestarts > 3
```

## Alerting

### Azure Monitor Alert

We set up an action group for email notifications:
```bash
az monitor action-group create \
  --name "aks-alerts-email" \
  --resource-group "rg-aks-gitops-demo" \
  --short-name "aksalert"

az monitor action-group update \
  --name "aks-alerts-email" \
  --resource-group "rg-aks-gitops-demo" \
  --add-action email admin your@email.com
```

Scheduled query alert for pod restarts:
```bash
az monitor scheduled-query create \
  --name "aks-pod-restart-alert" \
  --resource-group "rg-aks-gitops-demo" \
  --condition "count 'q' > 0" \
  --condition-query q="KubePodInventory | where TimeGenerated > ago(15m) | summarize MaxRestarts=max(ContainerRestartCount) by Name, Namespace | where MaxRestarts > 3" \
  --evaluation-frequency 15m \
  --window-size 15m \
  --severity 2 \
  --action-groups "/subscriptions/SUB_ID/resourceGroups/rg-aks-gitops-demo/providers/microsoft.insights/actionGroups/aks-alerts-email"
```

### Prometheus Alerting

Alertmanager is included in the stack. Example custom alert:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: audiobookshelf-alerts
  namespace: monitoring
spec:
  groups:
  - name: audiobookshelf
    interval: 30s
    rules:
    - alert: HighMemoryUsage
      expr: |
        (container_memory_working_set_bytes{namespace="audiobookshelf"} 
        / container_spec_memory_limit_bytes{namespace="audiobookshelf"}) > 0.9
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage in audiobookshelf"
```

## Troubleshooting

**No data in Container Insights**: Check if ama-logs pods are running in kube-system.

**KQL query errors**: Verify column names with `TableName | take 1`.

**Grafana not loading**: Check pod status with `kubectl get pods -n monitoring | grep grafana`.

**No metrics in Grafana**: Verify Prometheus data source is configured. Check targets at http://localhost:9090/targets (after port-forward).

## Cost Notes

- Azure Monitor: First 5 GB/month free, then ~$2.50/GB
- Prometheus: Self-hosted, uses ~0.5GB memory
- Default retention: 30 days (Azure), 15 days (Prometheus)
