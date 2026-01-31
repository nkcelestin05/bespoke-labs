# Phase 5: PostgreSQL Kubernetes Resources

## Overview

In Phase 5, we create Kubernetes resources for deploying PostgreSQL as a stateful database service. This phase builds on the Helm chart structure from Phase 4 and prepares the database layer that our FastAPI application will connect to.

## What We've Created

We've added three new Kubernetes template files to `wiki-chart/templates/`:

1. **postgresql-pvc.yaml** - PersistentVolumeClaim
2. **postgresql-deployment.yaml** - Deployment
3. **postgresql-service.yaml** - Service

Let's understand each one in detail.

---

## 1. PersistentVolumeClaim (postgresql-pvc.yaml)

### What It Does

A **PersistentVolumeClaim (PVC)** is like a "storage request ticket" that your application uses to claim persistent storage from the Kubernetes cluster.

```yaml
storage: {{ .Values.postgresql.persistence.size }}  # e.g., "1Gi"
accessModes:
  - ReadWriteOnce
```

### Why We Need It for Databases

Databases require **persistent storage** that survives pod restarts. Here's why:

| Without PVC | With PVC |
|-------------|----------|
| ❌ Data lost when pod crashes | ✅ Data persists across restarts |
| ❌ Data lost when pod is deleted | ✅ Data survives pod deletion |
| ❌ Every restart = empty database | ✅ Database state is preserved |

### How It Works

```
┌─────────────────────────────────────────────┐
│  Kubernetes Cluster                         │
│                                             │
│  ┌───────────────┐      ┌────────────────┐ │
│  │ PostgreSQL    │      │ Physical       │ │
│  │ Pod           │◄─────┤ Storage Volume │ │
│  └───────────────┘      └────────────────┘ │
│         ▲                                   │
│         │ Claims Storage                    │
│         │                                   │
│  ┌──────┴────────┐                         │
│  │ PVC           │                         │
│  │ (Storage      │                         │
│  │  Request)     │                         │
│  └───────────────┘                         │
└─────────────────────────────────────────────┘
```

### Key Concepts

**Access Modes:**
- `ReadWriteOnce (RWO)`: Volume can be mounted by a single node for read/write
- Perfect for databases, which typically run on one pod
- Other modes include `ReadOnlyMany` and `ReadWriteMany`

**Storage Classes:**
- Different storage classes offer different performance/cost characteristics
- Example: `standard`, `fast-ssd`, `slow-backup`
- If omitted, the cluster's default storage class is used

### Values from values.yaml

```yaml
postgresql:
  persistence:
    size: "1Gi"  # Can be easily changed without editing templates
```

---

## 2. Deployment (postgresql-deployment.yaml)

### What It Does

A **Deployment** manages your PostgreSQL pods, ensuring they're always running and properly configured. It's like a supervisor that:

- Keeps the desired number of pods running
- Restarts pods if they crash
- Handles rolling updates when you change configuration

### Key Components

#### Environment Variables

These configure PostgreSQL when it first starts:

```yaml
env:
- name: POSTGRES_DB
  value: {{ .Values.postgresql.database }}    # e.g., "wikidb"
- name: POSTGRES_USER
  value: {{ .Values.postgresql.username }}    # e.g., "postgres"
- name: POSTGRES_PASSWORD
  value: {{ .Values.postgresql.password }}    # e.g., "postgres"
- name: PGDATA
  value: /var/lib/postgresql/data/pgdata
```

**Why PGDATA?**
PostgreSQL stores data in `/var/lib/postgresql/data` by default. However, when mounting a volume to this path, there might be a `lost+found` directory that can cause initialization issues. Setting `PGDATA` to a subdirectory (`/var/lib/postgresql/data/pgdata`) avoids this problem.

#### Volume Mounts

This connects the PVC to the container:

```yaml
volumeMounts:
- name: postgresql-storage
  mountPath: /var/lib/postgresql/data

volumes:
- name: postgresql-storage
  persistentVolumeClaim:
    claimName: {{ include "wiki-chart.fullname" . }}-postgresql-pvc
```

**Flow:**
1. PVC requests storage from cluster
2. Deployment references PVC in volumes section
3. Container mounts volume at `/var/lib/postgresql/data`
4. PostgreSQL writes data to this path
5. Data persists on the volume even if pod dies

#### Health Probes

**Liveness Probe:**
Checks if the container is alive and functioning:

```yaml
livenessProbe:
  exec:
    command:
    - /bin/sh
    - -c
    - pg_isready -U {{ .Values.postgresql.username }}
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
```

- If this fails 3 times in a row, Kubernetes **restarts the container**
- Waits 30 seconds before first check (database needs startup time)
- `pg_isready` is a PostgreSQL utility that checks server status

**Readiness Probe:**
Checks if the container is ready to accept traffic:

```yaml
readinessProbe:
  exec:
    command:
    - /bin/sh
    - -c
    - pg_isready -U {{ .Values.postgresql.username }}
  initialDelaySeconds: 5
  periodSeconds: 5
```

- If this fails, the pod **won't receive traffic** from the service
- Starts checking sooner (5 seconds vs 30)
- Prevents routing traffic to unready database

#### Resource Limits

Ensures PostgreSQL doesn't consume excessive cluster resources:

```yaml
resources:
  requests:
    memory: {{ .Values.postgresql.resources.requests.memory }}  # e.g., "256Mi"
    cpu: {{ .Values.postgresql.resources.requests.cpu }}        # e.g., "250m"
  limits:
    memory: {{ .Values.postgresql.resources.limits.memory }}    # e.g., "512Mi"
    cpu: {{ .Values.postgresql.resources.limits.cpu }}          # e.g., "500m"
```

- **Requests**: Guaranteed resources (minimum allocation)
- **Limits**: Maximum resources (hard cap)
- Prevents one pod from starving others

---

## 3. Service (postgresql-service.yaml)

### What It Does

A **Service** provides a stable network endpoint for accessing PostgreSQL. Think of it as a permanent phone number that always reaches your database, even if the physical pod changes.

### Why We Need It

```
Problem: Pods are ephemeral
┌─────────────────┐
│ Pod 1           │
│ IP: 10.0.0.5    │ ◄── App connects here
└─────────────────┘
        ↓ Pod crashes and restarts
┌─────────────────┐
│ Pod 2           │
│ IP: 10.0.0.8    │ ◄── New IP! App connection breaks
└─────────────────┘

Solution: Use a Service
┌─────────────────┐
│ Service         │
│ DNS: postgres   │ ◄── App connects here (stable!)
│ IP: 10.96.0.1   │
└─────────────────┘
        ↓ Routes to current pod
┌─────────────────┐
│ PostgreSQL Pod  │
│ IP: any         │ ◄── IP can change, service adapts
└─────────────────┘
```

### Service Type: ClusterIP

```yaml
type: ClusterIP
```

**ClusterIP** means the service is only accessible **within the cluster**:

- ✅ Secure: Not exposed to the internet
- ✅ Perfect for databases (should never be public)
- ✅ Other pods can connect using DNS name
- ❌ Cannot be accessed from outside the cluster

Other service types:
- `NodePort`: Exposes service on each node's IP
- `LoadBalancer`: Creates external load balancer (cloud providers)

### How Internal Networking Works

```yaml
ports:
- port: {{ .Values.postgresql.service.port }}  # e.g., 5432
  targetPort: 5432
  protocol: TCP
```

**Port vs TargetPort:**
- `port`: What other pods connect to on the Service
- `targetPort`: What port the container is actually listening on

**Example Flow:**

```
┌────────────────────────────────────────────────────┐
│                                                    │
│  1. FastAPI pod wants to connect to database      │
│                                                    │
│  ┌──────────────┐                                 │
│  │ FastAPI Pod  │                                 │
│  │              │                                 │
│  │ DB_HOST=     │                                 │
│  │ "wiki-chart- │                                 │
│  │  postgresql" │                                 │
│  └──────┬───────┘                                 │
│         │                                         │
│         │ 2. DNS resolves to Service IP           │
│         ▼                                         │
│  ┌──────────────┐                                 │
│  │ Service      │                                 │
│  │ ClusterIP:   │                                 │
│  │ 10.96.0.1    │                                 │
│  │ Port: 5432   │                                 │
│  └──────┬───────┘                                 │
│         │                                         │
│         │ 3. Routes to pod matching selector      │
│         ▼                                         │
│  ┌──────────────┐                                 │
│  │ PostgreSQL   │                                 │
│  │ Pod          │                                 │
│  │ IP: 10.0.0.8 │                                 │
│  │ Port: 5432   │                                 │
│  └──────────────┘                                 │
│                                                    │
└────────────────────────────────────────────────────┘
```

### Selectors

```yaml
selector:
  {{- include "wiki-chart.selectorLabels" . | nindent 4 }}
  app.kubernetes.io/component: database
```

The service uses **selectors** to find which pods to route traffic to. These must match the labels on the PostgreSQL deployment pods.

---

## How Values are Templated from values.yaml

All three templates use Helm templating to pull values from `values.yaml`. This allows easy configuration changes without editing the templates.

### Example Template Expressions

| Template Expression | Values.yaml Path | Example Value |
|---------------------|------------------|---------------|
| `{{ .Values.postgresql.image }}` | `postgresql.image` | `postgres:16-alpine` |
| `{{ .Values.postgresql.persistence.size }}` | `postgresql.persistence.size` | `1Gi` |
| `{{ .Values.postgresql.database }}` | `postgresql.database` | `wikidb` |
| `{{ .Values.postgresql.username }}` | `postgresql.username` | `postgres` |
| `{{ .Values.postgresql.password }}` | `postgresql.password` | `postgres` |
| `{{ .Values.postgresql.service.port }}` | `postgresql.service.port` | `5432` |

### Helper Functions

```yaml
{{ include "wiki-chart.fullname" . }}
{{- include "wiki-chart.labels" . | nindent 4 }}
{{- include "wiki-chart.selectorLabels" . | nindent 4 }}
```

These are defined in `_helpers.tpl` and provide:
- Consistent naming across resources
- Standard labels for organization
- Selector labels for service/pod matching

---

## Complete Resource Lifecycle

Here's how all three resources work together:

```
Step 1: Create PVC
┌────────────────────────────────────┐
│ PersistentVolumeClaim              │
│ "I need 1Gi of storage"            │
└────────────────┬───────────────────┘
                 │
                 ▼
         Cluster allocates storage
                 │
                 ▼
┌────────────────────────────────────┐
│ PersistentVolume (PV)              │
│ Physical storage: 1Gi              │
└────────────────┬───────────────────┘
                 │
Step 2: Create Deployment            │
┌────────────────┴───────────────────┐
│ Deployment                         │
│ - Creates pod                      │
│ - Mounts PVC as volume             │
│ - Configures environment           │
│ - Sets up health probes            │
└────────────────┬───────────────────┘
                 │
                 ▼
         Pod starts running
                 │
Step 3: Create Service               │
┌────────────────┴───────────────────┐
│ Service                            │
│ - Creates stable DNS name          │
│ - Routes traffic to pod            │
│ - Type: ClusterIP (internal only)  │
└────────────────────────────────────┘
                 │
                 ▼
      Database is ready to use!
┌────────────────────────────────────┐
│ Other pods can connect using:      │
│ host: wiki-chart-postgresql        │
│ port: 5432                         │
└────────────────────────────────────┘
```

---

## Testing the Templates (Preview)

Once we have all phases complete, you can test these templates with:

```bash
# Validate syntax
helm template wiki-chart ./wiki-chart

# See what would be created (dry-run)
helm install wiki-release ./wiki-chart --dry-run --debug

# Actually deploy
helm install wiki-release ./wiki-chart

# Check status
kubectl get pvc
kubectl get deployments
kubectl get services
kubectl get pods
```

---

## Security Considerations

### Current Setup (Development)

```yaml
postgresql:
  password: "postgres"  # Plain text in values.yaml
```

### Production Best Practices

For production, use Kubernetes Secrets:

```yaml
# Create a secret
kubectl create secret generic postgresql-secret \
  --from-literal=password=your-secure-password

# Reference in deployment
env:
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgresql-secret
      key: password
```

Benefits:
- Passwords not stored in plain text
- Can be encrypted at rest
- Separate from code repository

---

## Next Steps: Phase 6

In Phase 6, we'll create similar resources for:
- **FastAPI Application Deployment**: Run our Python application
- **FastAPI Service**: Expose the API internally
- **ConfigMap**: Store environment variables for database connection

The FastAPI deployment will use the PostgreSQL service name to connect to the database:

```python
# FastAPI will use these environment variables:
DB_HOST = "wiki-chart-postgresql"  # The service name!
DB_PORT = "5432"
DB_NAME = "wikidb"
```

---

## Summary

Phase 5 establishes the database foundation with:

1. **PersistentVolumeClaim**: Ensures data survives pod restarts
2. **Deployment**: Manages PostgreSQL pods with proper configuration
3. **Service**: Provides stable network access for other pods

These three resources work together to create a production-ready database deployment that:
- ✅ Persists data across restarts
- ✅ Self-heals with health probes
- ✅ Provides stable networking
- ✅ Uses configurable values from Helm
- ✅ Isolates database from external access

The templates are fully documented with comments explaining each concept, making them educational resources as well as functional Kubernetes manifests.
