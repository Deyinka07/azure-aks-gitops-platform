# azure-aks-gitops-platform

Production-grade Kubernetes platform on Azure AKS with GitOps, CI/CD pipelines, and observability.

## What's in here

- **Infrastructure as Code** — Terraform configs for AKS, networking, and Azure resources
- **GitOps with FluxCD** — Cluster state managed declaratively via Git
- **CI/CD Pipelines** — Both GitHub Actions and Azure DevOps
- **Monitoring Stack** — Prometheus + Grafana via kube-prometheus-stack
- **Security Policies** — RBAC roles, network policies, pod security standards

## Architecture
```
┌─────────────────┐     ┌─────────────────┐
│  GitHub Actions │     │  Azure DevOps   │
│  (ghcr.io)      │     │  (ACR)          │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     ▼
              ┌──────────────┐
              │   FluxCD     │
              │   (GitOps)   │
              └──────┬───────┘
                     ▼
              ┌──────────────┐
              │   AKS        │
              │   Cluster    │
              └──────────────┘
```

## CI/CD

### GitHub Actions

Workflow in `.github/workflows/`:
- Builds Docker images from `audiobookshelf-custom/`
- Runs Trivy security scans
- Pushes to GitHub Container Registry (`ghcr.io`)
- Path filtering — only triggers on relevant changes

### Azure DevOps

Alternative pipeline in `azure-pipelines.yml`:
- Org: `deyinka007`
- Project: `audiobookshelf-pipeline`  
- Registry: `deyinkaacr.azurecr.io`

Note: Azure DevOps free tier requires parallelism approval before pipelines run.

## Monitoring

Prometheus and Grafana deployed via Helm:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring
```

Access Grafana:
```bash
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
```

Default credentials: `admin` / `prom-operator`

## Container Registries

| Registry | URL | Use Case |
|----------|-----|----------|
| GitHub Container Registry | `ghcr.io/deyinka07` | GitHub Actions builds |
| Azure Container Registry | `deyinkaacr.azurecr.io` | Azure DevOps builds |

## Project Structure
```
.
├── .github/workflows/    # GitHub Actions CI/CD
├── audiobookshelf-custom/# Custom container builds
├── cluster/              # FluxCD cluster configs
├── docs/                 # Detailed documentation
├── manifests/            # Kubernetes manifests
├── terraform/            # Infrastructure as Code
└── azure-pipelines.yml   # Azure DevOps pipeline
```

## Documentation

- [Implementation Guide](docs/IMPLEMENTATION.md) — Full technical walkthrough
- [Infrastructure](docs/INFRASTRUCTURE.md) — Terraform and AKS setup
- [GitOps](docs/GITOPS.md) — FluxCD configuration
- [Observability](docs/OBSERVABILITY.md) — Monitoring and alerting
- [Security](docs/SECURITY.md) — RBAC, network policies, pod security

## Quick Start

1. Deploy infrastructure:
```bash
   cd terraform
   terraform init
   terraform apply
```

2. Bootstrap FluxCD:
```bash
   flux bootstrap github \
     --owner=Deyinka07 \
     --repository=azure-aks-gitops-platform \
     --path=cluster
```

3. Verify:
```bash
   flux get all
   kubectl get pods -A
```
