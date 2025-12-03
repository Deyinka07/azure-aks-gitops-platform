# Security Implementation

Defense-in-depth security architecture with RBAC, Pod Security Standards, and Network Policies.

## Security Layers
```
Layer 1: RBAC (WHO can do WHAT)
  ├── ServiceAccounts (identity)
  ├── Roles (permissions)
  └── RoleBindings (connection)
  
Layer 2: Pod Security Standards (WHAT pods can DO)
  ├── Baseline enforcement
  ├── Block privileged containers
  └── Require non-root users
  
Layer 3: Network Policies (WHAT pods can TALK TO)
  ├── Default deny all
  ├── Explicit allows
  └── Micro-segmentation
```

**Defense in depth**: Multiple security controls working together. If one layer is bypassed, others provide protection.

## Layer 1: RBAC

### Implemented Roles

| Role | Scope | Can Do | Cannot Do |
|------|-------|--------|-----------|
| **readonly-user** | Namespace | Read pods/logs/deployments | Create, delete anything |
| **developer** | Namespace | Deploy apps, delete pods | Delete deployments/services |
| **namespace-admin** | Namespace | Everything in namespace | Access other namespaces |
| **cluster-viewer** | Cluster-wide | Read all pods/deployments | Modify anything |

### Role Examples

**readonly-user** (observers, juniors):
```yaml
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]
```

**developer** (active developers):
```yaml
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "delete"]  # Can delete pods for testing
```

**Rationale**: Developers can deploy and test, but can't accidentally delete production services.

### Testing RBAC
```bash
# Test as readonly-user (should succeed)
kubectl get pods -n rbac-demo --as=system:serviceaccount:rbac-demo:readonly-user

# Try to delete (should fail)
kubectl delete pod test -n rbac-demo --as=system:serviceaccount:rbac-demo:readonly-user
# Expected: Error (Forbidden)
```

### RBAC Best Practices

- ✅ Principle of least privilege
- ✅ Service account per application
- ✅ Regular permission audits
- ❌ Avoid wildcards in production (`verbs: ["*"]`)

## Layer 2: Pod Security Standards

### Configuration

**Enforcement level**: Baseline (blocks dangerous practices)  
**Audit level**: Restricted (logs violations)  
**Warn level**: Restricted (shows warnings)

**Applied via namespace labels**:
```bash
kubectl label namespace rbac-demo \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

### Security Levels

**Baseline** (enforced):
- ❌ No privileged containers
- ❌ No host network/ports
- ❌ No hostPath volumes
- ❌ Limited capabilities

**Restricted** (audit/warn only):
- Must run as non-root
- Must drop ALL capabilities
- Must use seccomp profile

### Secure Pod Example
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

### Container Security Challenge

**Technical constraint**: Standard nginx requires root privileges

**Error encountered**:
```
mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
```

**Resolution**: Use security-hardened images
- `nginxinc/nginx-unprivileged` instead of `nginx`
- `bitnami/mysql` instead of `mysql`

**Lesson**: Many popular images aren't secure by default

### Testing Pod Security

**Insecure pod** (should be blocked):
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
spec:
  containers:
  - name: nginx
    image: nginx
    securityContext:
      privileged: true
