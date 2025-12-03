# Observability Implementation

Azure Monitor and Log Analytics configuration for comprehensive cluster monitoring and alerting.

## Architecture
```
AKS Cluster
  ├── ama-logs DaemonSet (collects logs + metrics)
  ↓
Log Analytics Workspace
  ├── ContainerLog (application logs)
  ├── Perf (performance metrics)
  ├── KubePodInventory (pod metadata)
  └── KubeNodeInventory (node information)
  ↓
Azure Monitor Alerts
  └── Scheduled query rules + action groups
```

## Container Insights

**Configuration**: Enabled during Terraform provisioning

**Data collected**:
- CPU/memory usage (node and container)
- Disk I/O and network traffic
- Pod/container counts
- Restart counts
- Container logs (stdout/stderr)

**Verification**:
```bash
kubectl get pods -n kube-system -l app=ama-logs
# Should show ama-logs pods running
```

## KQL Query Language

**Core tables**:

| Table | Contents |
|-------|----------|
| ContainerLog | stdout/stderr logs |
| Perf | CPU, memory, disk, network |
| KubePodInventory | Pod metadata |
| KubeNodeInventory | Node information |

**Schema discovery** (critical first step):
```kusto
ContainerLog | take 1
```
Always check schema before writing queries to avoid column name errors.

## Production Queries

### Recent Application Logs
```kusto
ContainerLog
| where TimeGenerated > ago(1h)
| project TimeGenerated, Computer, LogEntry
| order by TimeGenerated desc
| take 50
```

### Error Detection
```kusto
ContainerLog
| where TimeGenerated > ago(24h)
| where LogEntry contains "ERROR"
| project TimeGenerated, Computer, Name, LogEntry
| order by TimeGenerated desc
```

### CPU Usage Analysis
```kusto
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "K8SContainer"
| where CounterName == "cpuUsageNanoCores"
| summarize AvgCPU = avg(CounterValue) by InstanceName
| order by AvgCPU desc
```

### Pod Restart Monitoring (Alert Query)
```kusto
KubePodInventory
| where TimeGenerated > ago(15m)
| summarize MaxRestarts = max(ContainerRestartCount) by Name, Namespace
| where MaxRestarts > 3
```

## Alerting Configuration

### Action Group

**Created via CLI**:
```bash
az monitor action-group create \
  --name "aks-alerts-email" \
  --resource-group "rg-aks-gitops-demo" \
  --short-name "aksalert"

az monitor action-group update \
  --name "aks-alerts-email" \
  --resource-group "rg-aks-gitops-demo" \
  --add-action email admin deyinka007@hotmail.com
```

**Configuration**:
- Name: aks-alerts-email
- Type: Email notification
- Recipient: deyinka007@hotmail.com

### Scheduled Query Alert

**Alert**: Pod restart detection  
**Condition**: Pods restarting >3 times in 15 minutes  
**Evaluation**: Every 15 minutes  
**Severity**: Warning (level 2)

**CLI creation**:
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

**Key syntax**: `--condition "count 'q' > 0"` references query variable `q`

## CLI Automation

**Query execution**:
```bash
az monitor log-analytics query \
  --workspace "WORKSPACE_ID" \
  --analytics-query "ContainerLog | take 10" \
  --output table
```

**Output management techniques**:
- Limit results: `| take 10`
- Truncate columns: `substring(LogEntry, 0, 100)`
- Pipe to less: `| less -S`
- Save to file: `--output json > results.json`
- Aggregate: `| summarize count()`

## Container Insights Dashboard

**Access**: Azure Portal → Monitor → Containers → Select cluster

**Views**:
- **Cluster**: Overall health, node status, pod counts
- **Nodes**: Per-node metrics, CPU/memory
- **Controllers**: Deployment/ReplicaSet health
- **Containers**: Individual container metrics

## Query Techniques

**Time filtering**:
```kusto
where TimeGenerated > ago(1h)      // Last hour
where TimeGenerated > ago(24h)     // Last day
```

**Aggregation**:
```kusto
| summarize count() by Computer
| summarize avg(Value) by Resource
| summarize max(RestartCount)
```

**Filtering**:
```kusto
| where LogEntry contains "error"
| where Value > 1000
```

**Projection**:
```kusto
| project TimeGenerated, Message    // Select columns
| order by TimeGenerated desc       // Sort
| take 50                            // Limit results
```

## Monitoring Best Practices

**Query optimization**:
- ✅ Filter early with `where` clauses
- ✅ Check schema before writing
- ✅ Use `take` during development
- ✅ Aggregate when possible

**Alert configuration**:
- Set realistic thresholds
- Use appropriate severity levels
- Test before production
- Prevent alert fatigue

**Cost management**:
- First 5 GB/month free
- Configure appropriate retention (30 days)
- Filter unnecessary logs
- Archive old logs to storage

## Troubleshooting

**No data in Container Insights**:
```bash
kubectl get pods -n kube-system | grep ama-logs
# Verify ama-logs pods are running
```

**KQL query errors**:
- Check schema: `TableName | take 1`
- Verify column names match exactly

**Alert not triggering**:
- Test query returns results
- Verify action group configuration
- Check alert is enabled

## Production Monitoring Strategy

**Metrics to monitor**:
- Node CPU/memory (capacity planning)
- Pod restart patterns (stability)
- Container exit codes (failures)
- Application error rates

**Alert hierarchy**:
- **Critical**: Cluster unreachable, multiple node failures
- **Warning**: Pod restarts, resource saturation
- **Info**: Configuration changes, deployments

