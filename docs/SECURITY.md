# Security Implementation

Defense-in-depth approach with four layers: RBAC, Pod Security Standards, Network Policies, and vulnerability scanning.

## Security Layers
```
Layer 1: RBAC           → WHO can do WHAT
Layer 2: Pod Security   → WHAT pods can DO
Layer 3: Network Policy → WHAT can TALK to WHAT
Layer 4: Scanning       → WHAT's IN the images
```

## Layer 1: RBAC

Four roles implemented:

| Role | Scope | Permissions |
|------|-------|-------------|
| readonly-user | Namespace | View pods and logs |
| developer | Namespace | Deploy apps, delete pods (not deployments) |
| namespace-admin | Namespace | Full control within namespace |
| cluster-viewer | Cluster | Read-only across all namespaces |

Example readonly role:
```yaml
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]
```

Test it:
```bash
# Should work
kubectl get pods -n rbac-demo --as=system:serviceaccount:rbac-demo:readonly-user

# Should fail
kubectl delete pod test -n rbac-demo --as=system:serviceaccount:rbac-demo:readonly-user
```

## Layer 2: Pod Security Standards

Applied via namespace labels:
```bash
kubectl label namespace rbac-demo \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

**Baseline** (enforced): No privileged containers, no host network, no hostPath volumes.

**Restricted** (audit/warn): Must run as non-root, drop all capabilities, use seccomp.

Secure pod example:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginxinc/nginx-unprivileged:1.25-alpine
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
```

### The nginx problem

Standard `nginx` image requires root and fails with PSS:
```
mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
```

Solution: Use `nginxinc/nginx-unprivileged` instead. Many popular images aren't secure by default.

## Layer 3: Network Policies

Default deny all traffic:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: rbac-demo
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

Then allow specific traffic:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-nginx-ingress
spec:
  podSelector:
    matchLabels:
      app: nginx
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
```

**Current limitation**: Cluster was created with `networkPolicy: none`. Policies are defined but not enforced. Would need cluster recreation to enable.

## Layer 4: Vulnerability Scanning

Trivy integrated into GitHub Actions pipeline.

Pipeline behavior:
1. Build image
2. Scan with Trivy
3. CRITICAL vulnerabilities → pipeline fails, no deployment
4. HIGH/MEDIUM/LOW → pipeline continues, results uploaded

Current scan results for audiobookshelf-custom:
- CRITICAL: 0 (would block deployment)
- HIGH: 5 (tracked for remediation)
- MEDIUM: 23
- LOW: 11

Pipeline config:
```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH,MEDIUM,LOW'
    exit-code: '1'  # Fail on findings
```

Run locally:
```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image ghcr.io/deyinka07/azure-aks-gitops-platform/audiobookshelf-custom:latest
```

### Remediation SLAs

| Severity | Timeline | Action |
|----------|----------|--------|
| CRITICAL | Immediate | Block deployment until fixed |
| HIGH | 7 days | Prioritize in current sprint |
| MEDIUM | 30 days | Plan for upcoming release |
| LOW | Best effort | Fix when convenient |

## How the Layers Work Together

Scenario: Attacker exploits application vulnerability and gets RCE.

1. **Scanning** should have caught known CVEs before deployment
2. **Pod Security** limits damage — container runs as non-root, no privilege escalation
3. **Network Policies** prevent lateral movement to other pods
4. **RBAC** blocks API access — container has no cluster permissions

Result: Blast radius limited to single container.

## Current Status

| Control | Status |
|---------|--------|
| RBAC | Implemented |
| Pod Security Standards | Enforced (Baseline) |
| Network Policies | Defined, not enforced |
| Vulnerability Scanning | Implemented in CI/CD |
| Secrets Management | SOPS + AGE |
| Audit Logging | Azure Monitor |

## Future Work

- Enable network policy engine (requires cluster recreation)
- Azure Key Vault integration
- Runtime security monitoring (Falco)
- OPA/Gatekeeper policy enforcement
