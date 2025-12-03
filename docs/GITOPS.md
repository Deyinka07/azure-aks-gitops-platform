# GitOps Implementation

FluxCD-based continuous deployment with SOPS-encrypted secrets management.

## Architecture
```
Developer → Git Push → GitHub Repository
                            ↓
                    FluxCD watches (every 5 min)
                            ↓
                    Applies to AKS Cluster
                            ↓
                    Self-healing active
```

**Model**: Pull-based (cluster pulls from Git)  
**Sync Interval**: 5 minutes  
**Secrets**: SOPS + AGE encryption

## FluxCD Components

| Controller | Purpose |
|-----------|---------|
| source-controller | Monitors Git repositories |
| kustomize-controller | Applies Kustomize manifests |
| helm-controller | Manages Helm releases |
| notification-controller | Sends alerts |

**Namespace**: `flux-system`

## Bootstrap
```bash
flux bootstrap github \
  --owner=Deyinka07 \
  --repository=azure-aks-gitops-platform \
  --branch=main \
  --path=./clusters/aks-cluster \
  --personal
```

**What this creates**:
- FluxCD system pods
- GitRepository resource pointing to this repo
- Kustomization watching cluster path
- Flux manifests committed back to Git

## GitOps Workflow

**Deployment process**:

1. Create application manifests
2. Commit to Git
3. Push to GitHub
4. Flux detects change (within 5 minutes)
5. Automatically applies to cluster

**Self-healing**: Manual changes reverted to Git state within 5 minutes

## Secrets Management

**SOPS Configuration**: AGE encryption

**Key generation**:
```bash
# Generate AGE key pair
age-keygen -o age.agekey

# Create Kubernetes secret (private key)
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=age.agekey
```

**Encryption**:
```bash
# Encrypt secret file
sops --encrypt --in-place secret.yaml

# Safe to commit
git add secret.yaml
git commit -m "feat: add encrypted secret"
git push
```

**Decryption**: Automatic by Flux using AGE key in cluster

**Security**:
- ✅ No plaintext credentials in Git
- ✅ Private key never leaves cluster
- ✅ Git history auditable

## Deployed Applications

### nginx-ingress
- **Type**: Helm release
- **Purpose**: Traffic routing
- **Chart**: ingress-nginx/ingress-nginx

### Audiobookshelf
- **Type**: Kustomize deployment
- **Structure**: Base + staging overlay
- **Purpose**: Media server

### Cloudflared
- **Type**: Kustomize deployment
- **Purpose**: Secure tunnel for external access
- **Credentials**: SOPS-encrypted

**Architecture**:
```
Internet → Cloudflare → Tunnel → Cluster → App
```
No exposed public IPs required.

## Monitoring Flux
```bash
# Check sync status
flux get all

# View logs
flux logs

# Force reconciliation
flux reconcile kustomization flux-system --with-source

# Reconcile specific app
flux reconcile kustomization apps
```

## Troubleshooting

**Issue**: Flux not syncing changes  
**Check**: `flux get sources git`  
**Solution**: Verify GitHub connectivity

**Issue**: SOPS decryption failing  
**Check**: `kubectl get secret -n flux-system sops-age`  
**Solution**: Verify AGE secret exists

**Issue**: Application not deploying  
**Check**: `flux logs --kind=Kustomization --name=apps`  
**Solution**: Review manifests for syntax errors

## Best Practices

**Commit messages**: Use conventional commits
- `feat:` New features
- `fix:` Bug fixes
- `chore:` Maintenance

**Directory structure**:
```
clusters/           # Cluster-specific config
  └── aks-cluster/  # This cluster
apps/               # Applications
  ├── base/         # Base configs
  └── production/   # Environment overlays
```

**Secret management**:
- ✅ Always encrypt with SOPS
- ✅ Store AGE private key in cluster only
- ✅ Never commit plaintext credentials
- ❌ Never commit AGE private key to Git

## GitOps vs Traditional CI/CD

| Aspect | GitOps | Traditional CI/CD |
|--------|--------|-------------------|
| Model | Pull-based | Push-based |
| Source of truth | Git | Pipeline |
| Drift detection | Automatic | Manual |
| Credentials | None needed | Pipeline needs kubeconfig |
| Self-healing | Built-in | Manual scripts |

**GitOps advantages**:
- Git history = audit trail
- Self-healing infrastructure
- No cluster credentials in CI/CD
- Declarative state management

## Disaster Recovery

**Cluster failure**: Bootstrap Flux on new cluster, all apps restore automatically from Git

**Recovery time**: ~5 minutes after infrastructure rebuild

