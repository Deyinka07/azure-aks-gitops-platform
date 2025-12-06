# Azure AKS GitOps Platform

Production-grade Kubernetes platform on Azure with GitOps, CI/CD pipelines, and comprehensive observability.

## Key Features

- **Infrastructure as Code** - Terraform-managed AKS cluster with remote state
- **GitOps Automation** - FluxCD for declarative, Git-driven deployments
- **CI/CD Pipelines** - GitHub Actions + Azure DevOps with security scanning
- **Observability** - Azure Monitor + Prometheus/Grafana stack
- **Security** - RBAC, Pod Security Standards, Network Policies, vulnerability scanning
- **Secrets Management** - SOPS/AGE encryption for GitOps-safe secrets

## Architecture

```
┌──────────────────┐     ┌──────────────────┐
│      GitHub      │     │   Azure DevOps   │
│    (Git + CI)    │     │     (CI/CD)      │
└────────┬─────────┘     └────────┬─────────┘
         │                        │
         │ GitOps (FluxCD)        │ Push images
         ▼                        ▼
┌─────────────────────────────────────────────────────────┐
│                    Azure AKS Cluster                    │
│                                                         │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐  │
│  │  flux-system  │ │  monitoring   │ │     apps      │  │
│  │               │ │               │ │               │  │
│  │  - source     │ │  - prometheus │ │  - audiobook  │  │
│  │  - kustomize  │ │  - grafana    │ │  - linkding   │  │
│  │               │ │  - alertmgr   │ │               │  │
│  └───────────────┘ └───────────────┘ └───────────────┘  │
│                                                         │
└───────────────────────────┬─────────────────────────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
┌──────────────────────┐     ┌──────────────────────┐
│    Azure Monitor     │     │ Container Registries │
│    Log Analytics     │     │                      │
│       Alerts         │     │  - ghcr.io           │
│                      │     │  - ACR               │
└──────────────────────┘     └──────────────────────┘
```

## Project Structure

```
.
├── .github/workflows/       # GitHub Actions CI/CD
│   └── docker-build.yml     # Container build + security scan
├── audiobookshelf-custom/   # Custom container builds
│   └── Dockerfile
├── cluster/                 # FluxCD cluster configs
│   ├── apps/                # Application deployments
│   ├── flux-system/         # FluxCD components
│   └── monitoring/          # Prometheus/Grafana HelmReleases
├── docs/                    # Documentation
├── manifests/               # Kubernetes manifests
├── terraform/               # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── azure-pipelines.yml      # Azure DevOps pipeline
└── README.md
```

## Quick Start

### Prerequisites

- Azure CLI installed and authenticated
- kubectl installed
- Flux CLI installed
- Terraform >= 1.0

### Deploy Infrastructure

```bash
# Clone repo
git clone https://github.com/Deyinka07/azure-aks-gitops-platform
cd azure-aks-gitops-platform

# Deploy with Terraform
cd terraform
terraform init
terraform plan
terraform apply

# Get AKS credentials
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)
```

### Bootstrap FluxCD

```bash
export GITHUB_TOKEN=<your-token>

flux bootstrap github \
  --owner=Deyinka07 \
  --repository=azure-aks-gitops-platform \
  --branch=main \
  --path=./cluster \
  --personal
```

### Verify Deployment

```bash
# Check FluxCD status
flux get kustomizations

# Check all pods
kubectl get pods -A
```

## CI/CD Pipelines

### GitHub Actions

Automated container builds with security scanning.

**Workflow:** `.github/workflows/docker-build.yml`

**Features:**
- Path filtering: triggers on `audiobookshelf-custom/*` changes
- Trivy vulnerability scanning
- CRITICAL vulnerabilities block deployment
- Multi-registry push (ghcr.io + ACR)
- Immutable tagging with commit SHA

**Published images:**
```
ghcr.io/deyinka07/azure-aks-gitops-platform/audiobookshelf-custom:<sha>
```

### Azure DevOps

**Organization:** `deyinka007`  
**Project:** `audiobookshelf-pipeline`  
**Pipeline:** `azure-pipelines.yml`

Builds and pushes to Azure Container Registry.

> Note: Azure DevOps free tier requires parallelism approval before pipelines run.

## Container Registries

| Registry | URL | Use Case |
|----------|-----|----------|
| GitHub Container Registry | `ghcr.io/deyinka07` | GitHub Actions builds |
| Azure Container Registry | `deyinkaacr.azurecr.io` | Azure DevOps builds |

## Monitoring & Observability

### Azure Monitor & Container Insights

Azure-native observability enabled on the AKS cluster.

**Features:**
- Container Insights for pod/container metrics
- Log Analytics workspace for centralized logging
- KQL queries for troubleshooting
- Azure Alerts for proactive monitoring

**Access:** Azure Portal > AKS cluster > Monitoring > Insights

**Example KQL query (container logs):**
```kql
ContainerLogV2
| where ContainerName == "audiobookshelf"
| order by TimeGenerated desc
| take 50
```

**Example KQL query (pod restarts):**
```kql
KubePodInventory
| where Namespace == "apps"
| summarize RestartCount = sum(PodRestartCount) by Name, bin(TimeGenerated, 1h)
| order by RestartCount desc
```

### Prometheus & Grafana

Deployed via FluxCD HelmRelease (GitOps pattern).

**Namespace:** `monitoring`

**HelmRelease manifests:**
- `cluster/monitoring/prometheus/release.yaml`
- `cluster/monitoring/grafana/release.yaml`

**Components:**
- Prometheus (metrics collection)
- Grafana (dashboards)
- Alertmanager
- Node Exporter
- kube-state-metrics

**Check deployment status:**
```bash
flux get helmreleases -n monitoring
kubectl get pods -n monitoring
```

**Access Grafana:**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```
Then open: http://localhost:3000

**Retrieve Grafana credentials:**
```bash
# Username: admin
# Password:
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d && echo
```

## Security

### RBAC

Role-based access control configured for:
- Cluster administrators
- Developers (namespace-scoped)
- Read-only access

### Pod Security Standards

Baseline Pod Security Standards enforced at namespace level.

### Network Policies

Default-deny with explicit allow rules:
- Frontend to Backend
- Backend to Database
- Ingress traffic

### Container Security Scanning

Trivy integrated in CI/CD pipeline:
- Scans all container images before push
- CRITICAL vulnerabilities block deployment
- Reports uploaded as workflow artifacts

## GitOps with FluxCD

All cluster state is managed declaratively via Git.

**How it works:**
1. Push changes to `cluster/` directory
2. FluxCD detects changes (1-minute interval)
3. FluxCD applies changes to cluster
4. Drift is automatically corrected

**Check sync status:**
```bash
flux get kustomizations
flux get helmreleases -A
```

**Force reconciliation:**
```bash
flux reconcile kustomization flux-system --with-source
```

### Secrets Management

Secrets encrypted with SOPS/AGE before committing to Git.

```bash
# Encrypt a secret
sops --encrypt --age <public-key> secret.yaml > secret.enc.yaml

# FluxCD decrypts automatically during apply
```

## Documentation

Detailed documentation available in `/docs`:

- **[Implementation Guide](docs/IMPLEMENTATION.md)** - Complete technical overview
- **[Infrastructure](docs/INFRASTRUCTURE.md)** - Terraform and AKS details
- **[GitOps](docs/GITOPS.md)** - FluxCD workflows
- **[Observability](docs/OBSERVABILITY.md)** - Monitoring setup
- **[Security](docs/SECURITY.md)** - RBAC, PSS, Network Policies

## Tech Stack

| Category | Technology |
|----------|------------|
| Cloud | Azure (AKS, ACR, Monitor, Key Vault) |
| Infrastructure | Terraform |
| GitOps | FluxCD |
| CI/CD | GitHub Actions, Azure DevOps |
| Containers | Docker, Kubernetes |
| Monitoring | Prometheus, Grafana, Azure Monitor |
| Security | Trivy, RBAC, Pod Security Standards |
| Secrets | SOPS/AGE |

## License

MIT
