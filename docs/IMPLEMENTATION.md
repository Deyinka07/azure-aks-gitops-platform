# Technical Implementation Guide

Azure AKS GitOps Platform - Complete technical reference covering infrastructure, GitOps, observability, and security.

## Architecture Overview
```
Azure Cloud
  ├── AKS Cluster (Terraform)
  │   ├── FluxCD (GitOps automation)
  │   ├── Applications (nginx-ingress, audiobookshelf, cloudflared)
  │   └── Security (RBAC, Pod Security, Network Policies)
  └── Azure Monitor + Log Analytics
```

## Implementation Phases

### Phase 1: Infrastructure (Terraform + AKS)
- Terraform-managed AKS cluster
- Log Analytics workspace integration
- Container Insights enabled
- Cost-optimized resource sizing

**Key files**: `infrastructure/main.tf`, `variables.tf`, `outputs.tf`

### Phase 2: GitOps (FluxCD)
- FluxCD bootstrap with GitHub integration
- SOPS-encrypted secrets (AGE encryption)
- Automated reconciliation (5-minute sync)
- Self-healing infrastructure

**Applications deployed**: nginx-ingress, audiobookshelf, cloudflared

### Phase 3: Observability (Azure Monitor)
- Container Insights for metrics
- KQL queries for log analysis
- Scheduled query alerts
- Email notifications via action groups

**Sample KQL**: Pod restart monitoring, error detection, CPU analysis

### Phase 4: Security (Defense in Depth)
- **RBAC**: 4 role types (readonly, developer, namespace-admin, cluster-viewer)
- **Pod Security Standards**: Baseline enforcement on namespaces
- **Network Policies**: Default deny with explicit allows (requires network policy engine)

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Infrastructure | Terraform |
| Orchestration | Azure AKS |
| GitOps | FluxCD |
| Secrets | SOPS + AGE |
| Ingress | nginx-ingress |
| Access | Cloudflare Tunnels |
| Monitoring | Azure Monitor + KQL |
| Security | RBAC, PSS, Network Policies |

## Key Design Decisions

**FluxCD over ArgoCD**: Native Kubernetes CRDs, better SOPS integration, pull-based model

**SOPS for Secrets**: Encrypted secrets in Git, seamless FluxCD integration, no external dependencies

**Azure Monitor over Prometheus**: Native Azure integration, no infrastructure overhead, KQL query power

**nginx-ingress over Traefik**: Industry standard, extensive documentation, enterprise adoption

## Technical Constraints

### Container Security Hardening
**Issue**: Standard nginx requires root privileges  
**Solution**: Used nginxinc/nginx-unprivileged variant  
**Lesson**: Popular images often aren't secure by default

### Network Policy Enforcement
**Issue**: Cluster created with `networkPolicy: none`  
**Solution**: Policies defined but not enforced (requires cluster recreation)  
**Lesson**: Network policies must be planned during initial provisioning

### KQL Schema Discovery
**Issue**: Queries failed due to incorrect column assumptions  
**Solution**: Always check schema with `TableName | take 1` first  
**Lesson**: Verify schema before writing queries

## Operational Commands
```bash
# Start/stop cluster
az aks start --name aks-gitops-cluster --resource-group rg-aks-gitops-demo
az aks stop --name aks-gitops-cluster --resource-group rg-aks-gitops-demo

# Query logs
az monitor log-analytics query --workspace "ID" --analytics-query "KQL"

# Flux status
flux get all
flux reconcile kustomization flux-system --with-source

# Test RBAC
kubectl get pods -n rbac-demo --as=system:serviceaccount:rbac-demo:readonly-user
```

## Cost Management

- **Running**: ~£1.70/day
- **Stopped**: ~£0.30/day  
- **Total 4 weeks**: ~£50-60

**Optimization**: Use `az aks stop` when not in use, delete completely for extended periods

## Future Enhancements

- CI/CD pipeline (GitHub Actions)
- Network policy engine enablement
- Azure Key Vault integration
- Horizontal Pod Autoscaling
- Cost optimization dashboards

## Documentation

- [Infrastructure Details](INFRASTRUCTURE.md)
- [GitOps Configuration](GITOPS.md)
- [Monitoring Setup](OBSERVABILITY.md)
- [Security Implementation](SECURITY.md)

