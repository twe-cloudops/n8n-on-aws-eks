# Blueprint: Pod Security Standards

**Priority**: HIGH
**Effort**: 1 day
**Impact**: Hardens container security, prevents privilege escalation

---

## Problem

Containers run as root with no security restrictions, violating security best practices.

---

## Solution

Implement Pod Security Standards (PSS) with restricted profile and proper security contexts.

---

## Implementation

### Step 1: Enable PSS on Namespace

**File**: `manifests/00-namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: n8n
  labels:
    name: n8n
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: n8n-quota
  namespace: n8n
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    persistentvolumeclaims: "4"
```

### Step 2: Update PostgreSQL Deployment

**File**: `manifests/03-postgres-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-simple
  namespace: n8n
  labels:
    app: postgres-simple
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres-simple
  template:
    metadata:
      labels:
        app: postgres-simple
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: false  # PostgreSQL needs write access
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_PASSWORD
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_DB
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: tmp
          mountPath: /tmp
        - name: run
          mountPath: /var/run/postgresql
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - $(POSTGRES_USER)
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - $(POSTGRES_USER)
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
      - name: tmp
        emptyDir: {}
      - name: run
        emptyDir: {}
```

### Step 3: Update n8n Deployment

**File**: `manifests/06-n8n-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n-simple
  namespace: n8n
  labels:
    app: n8n-simple
spec:
  replicas: 1
  selector:
    matchLabels:
      app: n8n-simple
  template:
    metadata:
      labels:
        app: n8n-simple
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      initContainers:
      - name: volume-permissions
        image: busybox:1.36
        command: ["sh", "-c", "chmod 777 /home/node/.n8n"]
        securityContext:
          runAsUser: 0  # Init container needs root to set permissions
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
            add:
            - CHOWN
            - FOWNER
        volumeMounts:
        - name: n8n-storage
          mountPath: /home/node/.n8n
      containers:
      - name: n8n
        image: n8nio/n8n:latest
        ports:
        - containerPort: 5678
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: false  # n8n needs write access
        env:
        - name: DB_TYPE
          value: postgresdb
        - name: DB_POSTGRESDB_HOST
          value: postgres-service-simple.n8n.svc.cluster.local
        - name: DB_POSTGRESDB_PORT
          value: "5432"
        - name: DB_POSTGRESDB_DATABASE
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_DB
        - name: DB_POSTGRESDB_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_NON_ROOT_USER
        - name: DB_POSTGRESDB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_NON_ROOT_PASSWORD
        - name: N8N_SECURE_COOKIE
          value: "false"
        - name: N8N_PROTOCOL
          value: http
        - name: N8N_PORT
          value: "5678"
        - name: N8N_METRICS
          value: "true"
        volumeMounts:
        - name: n8n-storage
          mountPath: /home/node/.n8n
        - name: tmp
          mountPath: /tmp
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /healthz
            port: 5678
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /healthz
            port: 5678
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
      volumes:
      - name: n8n-storage
        persistentVolumeClaim:
          claimName: n8n-pvc
      - name: tmp
        emptyDir: {}
```

---

## Testing

### Verify PSS Enforcement

```bash
# Check namespace labels
kubectl get namespace n8n -o yaml | grep pod-security

# Try to create a privileged pod (should fail)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged
  namespace: n8n
spec:
  containers:
  - name: test
    image: nginx
    securityContext:
      privileged: true
EOF
# Expected: Error - violates PodSecurity "restricted:latest"
```

### Verify Security Contexts

```bash
# Check pod security context
kubectl get pod -n n8n -o jsonpath='{.items[*].spec.securityContext}'

# Check container security context
kubectl get pod -n n8n -o jsonpath='{.items[*].spec.containers[*].securityContext}'

# Verify non-root user
kubectl exec -n n8n deployment/n8n-simple -- id
# Expected: uid=1000 gid=1000

kubectl exec -n n8n deployment/postgres-simple -- id
# Expected: uid=999(postgres) gid=999(postgres)
```

### Test Application Functionality

```bash
# Verify n8n is accessible
kubectl port-forward -n n8n service/n8n-service-simple 8080:80

# Test in browser: http://localhost:8080

# Verify database connectivity
kubectl exec -n n8n deployment/n8n-simple -- \
  nc -zv postgres-service-simple 5432
```

---

## Troubleshooting

### Permission Denied Errors

If you see permission errors:

```bash
# Check volume permissions
kubectl exec -n n8n deployment/n8n-simple -- ls -la /home/node/.n8n

# Fix permissions (if needed)
kubectl delete pod -n n8n -l app=n8n-simple
# Init container will fix permissions on restart
```

### PostgreSQL Won't Start

```bash
# Check logs
kubectl logs -n n8n deployment/postgres-simple

# Common issue: PGDATA permissions
# Solution: Ensure fsGroup is set correctly (999 for postgres)
```

### Read-Only Filesystem Issues

Some applications need write access to specific paths:

```yaml
# Add emptyDir volumes for writable paths
volumes:
- name: tmp
  emptyDir: {}
- name: cache
  emptyDir: {}

volumeMounts:
- name: tmp
  mountPath: /tmp
- name: cache
  mountPath: /var/cache
```

---

## Security Benefits

✅ Containers run as non-root users
✅ Privilege escalation prevented
✅ Unnecessary capabilities dropped
✅ Seccomp profile applied
✅ PSS violations blocked at admission

---

## PSS Profiles Comparison

| Profile | Description | Use Case |
|---------|-------------|----------|
| **Privileged** | Unrestricted | Legacy apps, system components |
| **Baseline** | Minimally restrictive | Most apps |
| **Restricted** | Heavily restricted | Security-sensitive apps |

We use **Restricted** for maximum security.

---

## Exceptions

If you need to relax restrictions for specific pods:

```yaml
# Add label to pod
metadata:
  labels:
    pod-security.kubernetes.io/enforce: baseline
```

Or use namespace-level exceptions:

```yaml
# Namespace with baseline for specific workloads
apiVersion: v1
kind: Namespace
metadata:
  name: n8n-legacy
  labels:
    pod-security.kubernetes.io/enforce: baseline
```

---

## Monitoring

Monitor PSS violations:

```bash
# Check audit logs
kubectl get events -n n8n | grep PodSecurity

# Check warnings
kubectl get pods -n n8n -o yaml | grep -A 5 "pod-security"
```

---

**Status**: Ready to implement
**Dependencies**: Kubernetes 1.23+
**Validation**: All pods start successfully, PSS violations blocked
