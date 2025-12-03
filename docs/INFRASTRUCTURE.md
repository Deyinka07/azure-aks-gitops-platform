# Infrastructure Implementation

Terraform-based Infrastructure as Code for AKS cluster provisioning with integrated monitoring.

## Resources Provisioned

| Resource | Purpose |
|----------|---------|
| Resource Group | `rg-aks-gitops-demo` (UK South) |
| AKS Cluster | `aks-gitops-cluster` (1 x Standard_B2s node) |
| Log Analytics | `law-aks-gitops-cluster` (30-day retention) |
| Container Insights | Automatic metrics and log collection |

## Terraform Configuration

**Location**: `infrastructure/`

**Key files**:
- `main.tf` - Resource definitions
- `variables.tf` - Input parameters
- `outputs.tf` - Connection details
- `terraform.tfstate` - State tracking (not in Git)

**Sample resource**:
```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-gitops-cluster"
  location            = "uksouth"
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aks-gitops"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }
}
```

## Deployment Procedure
```bash
# Initialize Terraform
cd infrastructure
terraform init

# Review changes
terraform plan

# Apply configuration
terraform apply

# Connect to cluster
az aks get-credentials --name aks-gitops-cluster --resource-group rg-aks-gitops-demo
kubectl get nodes
```

## Resource Specifications

**Compute**:
- VM Size: Standard_B2s (2 vCPU, 4 GB RAM)
- Node Count: 1
- Rationale: Cost-effective for dev/test

**Networking**:
- Network Plugin: azure
- Network Policy: none (requires recreation to enable)
- DNS Prefix: aks-gitops

**Monitoring**:
- Container Insights: Enabled
- Log Analytics: 30-day retention
- Metrics: CPU, memory, disk, network, pod counts

## Cost Analysis

| Component | Monthly Cost |
|-----------|--------------|
| Compute (Standard_B2s) | £25-30 |
| Storage | £10-15 |
| Networking | £5-10 |
| Log Analytics | £5-10 |
| **Total** | **£45-65** |

**Optimization**:
- Stop cluster: `az aks stop` (saves ~£25-30/month)
- Delete entirely: `terraform destroy` (£0, rebuild in 15 mins)

## Cluster Configuration

**Enabled**:
- ✅ Azure CNI networking
- ✅ Container Insights
- ✅ System-assigned managed identity
- ✅ Kubernetes RBAC

**Not Enabled**:
- ❌ Network policy engine
- ❌ Azure Policy integration
- ❌ Availability zones

**Kubernetes Version**: 1.32.9

## Network Policy Limitation

**Current state**: `networkPolicy: none`

**Verification**:
```bash
az aks show --name aks-gitops-cluster \
  --resource-group rg-aks-gitops-demo \
  --query "networkProfile.networkPolicy"
# Output: "none"
```

**Impact**: NetworkPolicy resources accepted but not enforced

**Resolution**: Requires cluster recreation with `--network-policy azure` or `--network-policy calico`

## Disaster Recovery

**Strategy**: Infrastructure as Code enables rapid rebuild

**Recovery procedure**:
```bash
# 1. Destroy failed cluster
terraform destroy

# 2. Recreate infrastructure  
terraform apply

# 3. Reconnect
az aks get-credentials --name aks-gitops-cluster --resource-group rg-aks-gitops-demo

# 4. Bootstrap Flux (restores all apps)
flux bootstrap github --owner=Deyinka07 --repository=azure-aks-gitops-platform \
  --branch=main --path=clusters/aks-cluster
```

**RTO**: ~15 minutes

## Production Recommendations

**For production deployment**:

1. **Multi-zone deployment**
```hcl
   default_node_pool {
     zones = ["1", "2", "3"]
   }
```

2. **Network policy engine**
```bash
   az aks create --network-policy azure
```

3. **Remote state backend**
```hcl
   backend "azurerm" {
     resource_group_name  = "rg-terraform-state"
     storage_account_name = "tfstate"
     container_name       = "tfstate"
     key                  = "aks.tfstate"
   }
```

4. **Separate node pools**
   - System pool (cluster services)
   - User pool (applications)

5. **Security enhancements**
   - Azure AD integration
   - Private cluster endpoint
   - Azure Key Vault integration

