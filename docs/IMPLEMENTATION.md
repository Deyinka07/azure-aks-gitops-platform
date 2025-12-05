# Technical Implementation Guide

Full technical reference for the Azure AKS GitOps platform.

## Architecture
```
Azure Cloud
├── AKS Cluster (Terraform-managed)
│   ├── FluxCD (GitOps)
│   ├── Apps: nginx-ingress, audiobookshelf, cloudflared
│   ├── Monitoring: Prometheus + Grafana
│   └── Security: RBAC, Pod Security, Network Policies
├── Azure Monitor + Log Analytics
├── Azure Container Registry (deyinkaacr.azurecr.io)
└── GitHub Container Registry (ghcr.io)
```

## Implementation Phases

### Phase 1: Infrastructure

Terraform-managed AKS cluster with Log Analytics and Container Insights enabled.

Key files: `terraform/main.tf`, `variables.tf`, `outputs.tf`

### Phase 2: GitOps

FluxCD bootstrapped with GitHub integration. Secrets encrypted with SOPS/AGE. Reconciliation runs every 5 minutes.

Deployed apps: nginx-ingress, audiobookshelf, cloudflared

### Phase 3: Observability

Dual monitoring approach:
- Azure Monitor for cloud-native integration and long-term retention
- Prometheus + Grafana for Kubernetes-native metrics and custom dashboards

See [OBSERVABILITY.md](OBSERVABILITY.md) for details.

### Phase 4: Security

Defense in depth with four layers:
- RBAC (4 role types)
- Pod Security Standards (Baseline enforcement)
- Network Policies (defined, pending enforcement)
- Vulnerability scanning (Trivy in CI/CD)

See [SECURITY.md](SECURITY.md) for details.

### Phase 5: CI/CD Pipelines

#### GitHub Actions

Pipeline in `.github/workflows/docker-build.yml`:
- Triggers on push to `main` when `audiobookshelf-custom/*` changes
- Builds Docker image
- Runs Trivy security scan (fails on CRITICAL)
- Pushes to ghcr.io with SHA-based tags

Images published to:
```
ghcr.io/deyinka07/azure-aks-gitops-platform/audiobookshelf-custom:main-<SHA>
```

Current scan results: 39 vulnerabilities (0 critical, 5 high, 34 medium/low)

#### Azure DevOps

Alternative pipeline in `azure-pipelines.yml`:
- Org: `deyinka007`
- Project: `audiobookshelf-pipeline`
- Registry: `deyinkaacr.azurecr.io`
- Status: Configured, awaiting Microsoft parallelism approval

## Tech Stack

| Component | Technology |
|-----------|------------|
| Infrastructure | Terraform |
| Orchestration | Azure AKS |
| GitOps | FluxCD |
| Secrets | SOPS + AGE |
| CI/CD | GitHub Actions, Azure DevOps |
| Registries | ghcr.io, Azure Container Registry |
| Security Scanning | Trivy |
| Ingress | nginx-ingress |
| Tunnel Access | Cloudflare Tunnels |
| Monitoring | Azure Monitor, Prometheus, Grafana |

## Design Decisions

**FluxCD over ArgoCD** — Native Kubernetes CRDs, better SOPS integration, pull-based model.

**SOPS for secrets** — Encrypted secrets live in Git, no external dependencies.

**Dual monitoring** — Prometheus for detailed metrics, Azure Monitor for cloud-native integration.

**Multi-registry CI/CD** — GitHub Actions for dev velocity, Azure DevOps for enterprise integration.

## Lessons Learned

**Container security hardening**: Standard nginx requires root. Use `nginxinc/nginx-unprivileged` instead.

**Network policy enforcement**: Must be enabled at cluster creation. Our cluster was created with `networkPolicy: none`, so policies are defined but not enforced.

**KQL schema discovery**: Always run `TableName | take 1` before writing queries. Column names aren't what you expect.

**Azure DevOps parallelism**: New orgs need manual approval for free parallel jobs. Plan for 2-3 business day delay.

## Operational Commands
```bash
# Cluster start/stop
az aks start --name aks-gitops-cluster --resource-group rg-aks-gitops-demo
az aks stop --name aks-gitops-cluster --resource-group rg-aks-gitops-demo

# FluxCD
flux get all
flux reconcile kustomization flux-system --with-source

# Monitoring
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Trigger pipeline manually
git commit --allow-empty -m "Trigger pipeline"
git push origin main

# Local Trivy scan
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image ghcr.io/deyinka07/azure-aks-gitops-platform/audiobookshelf-custom:latest
```

## Costs

- Running: ~£1.70/day
- Stopped: ~£0.30/day
- Monthly estimate: £50-60
- ACR (Basic): ~£5-10/month

Use `az aks stop` when not actively working.

## Project Timeline

- Weeks 1-2: Infrastructure + GitOps (Terraform, AKS, FluxCD)
- Weeks 3-4: Security + Observability (RBAC, PSS, Azure Monitor)
- Weeks 5-6: CI/CD + Advanced Monitoring (GitHub Actions, Prometheus/Grafana)

Total: ~6 weeks, ~100+ hours
