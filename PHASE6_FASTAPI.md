# Phase 6: FastAPI Kubernetes Resources

## Overview

In Phase 6, we create the Kubernetes resources needed to deploy our FastAPI application in the cluster. This phase builds on the PostgreSQL deployment from Phase 5, connecting our API to the database and making it accessible within the cluster.

**What we're deploying:**
- FastAPI application (the API service)
- Multiple replicas for high availability
- Health monitoring and automatic restarts
- Internal networking via Kubernetes Service

---

## Files Created

### 1. `fastapi-deployment.yaml`
Manages the FastAPI application pods with advanced features like init containers and health probes.

### 2. `fastapi-service.yaml`
Provides stable internal networking and load balancing across FastAPI pods.

---

## Detailed Component Explanation

### Part 1: Understanding the Deployment

#### What is a Deployment?

A **Deployment** is a Kubernetes controller that manages a set of identical pods. Think of it as a "pod manager" that ensures:
- The right number of pods are always running
- Pods are automatically restarted if they crash
- Updates are rolled out gradually (zero-downtime)
- Old versions can be rolled back if something breaks

**Key differences from StatefulSet (used for databases):**
- Deployments are for **stateless** applications (like our API)
- All pods are identical and interchangeable
- Pods can be killed and recreated freely without data loss
- Perfect for applications that don't store data locally

#### Replica Configuration

```yaml
replicas: {{ .Values.fastapi.replicaCount }}  # Default: 2
```

**Why run multiple replicas?**

1. **High Availability**: If one pod crashes, others continue serving traffic
2. **Load Distribution**: Traffic is spread across pods for better performance
3. **Zero-Downtime Deployments**: Old pods stay running while new ones start
4. **Resilience**: Node failures don't take down the entire application

**Example scenario:**
- You have 2 FastAPI pods running
- One pod crashes due to a bug
- Service automatically routes all traffic to the healthy pod
- Kubernetes automatically restarts the crashed pod
- Once healthy, both pods share the traffic again

---

### Part 2: Init Containers - Dependency Management

#### What is an Init Container?

An **init container** is a special container that runs **before** the main application container starts. It must complete successfully or the pod won't start.

**Why do we need this?**

```
Problem without init container:
1. FastAPI pod starts
2. Tries to connect to PostgreSQL
3. PostgreSQL isn't ready yet
4. FastAPI crashes
5. Kubernetes restarts FastAPI
6. Still not ready... crash again!
7. Repeat until PostgreSQL is ready (wasteful)
```

```
Solution with init container:
1. Init container starts
2. Waits until PostgreSQL is ready
3. Init container exits successfully
4. FastAPI starts and immediately connects
5. No crashes, no wasted restarts!
```

#### Our Init Container Implementation

```yaml
initContainers:
- name: wait-for-postgres
  image: busybox:1.36
  command:
  - sh
  - -c
  - |
    echo "Waiting for PostgreSQL to be ready..."
    until nc -z {{ include "wiki-chart.fullname" . }}-postgresql 5432; do
      echo "PostgreSQL is unavailable - sleeping"
      sleep 2
    done
    echo "PostgreSQL is ready!"
```

**How it works:**

1. **`busybox:1.36`**: Tiny Linux image (1-5MB) with basic networking tools
2. **`nc -z`**: Netcat in "zero I/O" mode - just checks if port is open
3. **`until ... do ... done`**: Bash loop that repeats until condition succeeds
4. **`sleep 2`**: Wait 2 seconds between connection attempts
5. **Service name**: Uses PostgreSQL service DNS name for connectivity check

**What's being checked:**
- Can we establish a TCP connection to PostgreSQL on port 5432?
- This means PostgreSQL is accepting connections (ready for queries)

**Resource limits:**
```yaml
resources:
  requests:
    cpu: "10m"      # 0.01 CPU cores (1% of one core)
    memory: "16Mi"  # 16 megabytes
  limits:
    cpu: "50m"      # 0.05 CPU cores
    memory: "32Mi"  # 32 megabytes
```
Init containers need minimal resources since they just check connectivity.

---

### Part 3: Environment Variables - Connecting to PostgreSQL

Environment variables configure the FastAPI application to connect to the database.

#### Database Connection Configuration

```yaml
env:
- name: DB_HOST
  value: {{ include "wiki-chart.fullname" . }}-postgresql
  
- name: DB_PORT
  value: "{{ .Values.postgresql.service.port }}"
  
- name: DB_NAME
  value: {{ .Values.postgresql.database.name }}
  
- name: DB_USER
  value: {{ .Values.postgresql.database.user }}
  
- name: DB_PASSWORD
  value: {{ .Values.postgresql.database.password }}
```

#### How FastAPI Uses These Variables

In `wiki-service/app/database.py`, our application reads these environment variables:

```python
import os
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

# Read environment variables (with defaults for local dev)
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "wikidb")

# Build PostgreSQL connection string
DATABASE_URL = f"postgresql+asyncpg://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# Create database engine
engine = create_async_engine(DATABASE_URL, pool_pre_ping=True)
```

#### DNS Resolution Magic

When FastAPI tries to connect to `DB_HOST=wiki-chart-postgresql`:

1. **DNS Query**: FastAPI asks Kubernetes DNS "Where is wiki-chart-postgresql?"
2. **DNS Response**: Kubernetes returns the ClusterIP of the PostgreSQL service (e.g., 10.96.0.15)
3. **Connection**: FastAPI connects to 10.96.0.15:5432
4. **Service Routing**: Service forwards traffic to the PostgreSQL pod
5. **Database Connection**: PostgreSQL authenticates and establishes connection

**Why use service name instead of pod IP?**
- Pod IPs change when pods restart
- Service IPs are stable and never change
- Service provides automatic failover if pod dies
- Service name is easier to remember and configure

#### Values from values.yaml

All these values come from `wiki-chart/values.yaml`:

```yaml
postgresql:
  database:
    name: wikidb
    user: postgres
    password: postgres  # ⚠️ CHANGE IN PRODUCTION!
  service:
    port: 5432
```

**Production security note:**
In production, use Kubernetes Secrets instead of plain text:

```yaml
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgres-secret
      key: password
```

---

### Part 4: Health Probes - Keeping Pods Healthy

Kubernetes uses health probes to monitor pod health and take action when problems occur.

#### Two Types of Probes

| Probe Type | Purpose | When it Fails |
|------------|---------|---------------|
| **Liveness** | "Is the app still alive?" | Kubernetes **restarts** the container |
| **Readiness** | "Is the app ready for traffic?" | Kubernetes **stops sending traffic** (but doesn't restart) |

#### Liveness Probe

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

**What this does:**

1. **Wait 30 seconds** after container starts (FastAPI needs time to initialize)
2. **Every 10 seconds**, send HTTP GET request to `http://localhost:8000/health`
3. **Wait 5 seconds** for response
4. If 3 consecutive checks fail, **restart the container**

**When would this trigger?**
- FastAPI process crashes or hangs
- Application enters an unrecoverable error state
- Database connection pool is exhausted and app can't recover
- Memory leak causes app to stop responding

**Why restart?**
- Many issues are fixed by restarting (clears hung connections, resets state)
- Fresh start often resolves transient problems
- Better than leaving a broken pod running

#### Readiness Probe

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

**What this does:**

1. **Wait 10 seconds** after container starts (faster than liveness)
2. **Every 5 seconds**, check if app is ready
3. **Wait 3 seconds** for response
4. If 3 consecutive checks fail, **remove pod from Service endpoints**

**When would this trigger?**
- Database connection temporarily lost
- App is overloaded and can't handle more requests
- Application is starting up and not ready yet
- Deployment is rolling out and old pods are shutting down

**Why not restart?**
- Issue might be temporary (e.g., database restart)
- Pod might recover on its own
- Restarting could make the problem worse (e.g., if database is down)
- Service just routes traffic to healthy pods instead

#### Liveness vs Readiness Example

**Scenario: Database connection pool exhausted**

```
With only liveness probe:
- App can't get DB connections (all in use)
- Continues receiving traffic from Service
- All requests fail with 500 errors
- Eventually liveness fails → pod restarts
- Problem: Users got errors while waiting for restart

With readiness probe:
- App can't get DB connections
- Readiness probe fails
- Service stops sending new traffic to this pod
- Traffic goes to other healthy pods
- Connections eventually free up
- Readiness probe succeeds → traffic resumes
- Problem: No user impact! Self-healing without restart
```

#### Health Endpoint Implementation

In `wiki-service/app/main.py`, we have a health endpoint:

```python
@app.get("/health")
async def health_check():
    """Health check endpoint for Kubernetes probes"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat()
    }
```

**What makes a good health check?**
- Fast (< 1 second response time)
- Lightweight (doesn't consume many resources)
- Accurate (actually checks if app is working)
- Optional: Check database connectivity, external dependencies

**Enhanced health check (optional improvement):**
```python
@app.get("/health")
async def health_check():
    try:
        # Check database connectivity
        await database.execute("SELECT 1")
        return {"status": "healthy"}
    except Exception as e:
        # Database is down
        raise HTTPException(status_code=503, detail="Database unavailable")
```

---

### Part 5: Resource Limits - Controlling Resource Usage

Resource limits ensure pods don't consume excessive cluster resources.

#### Resource Configuration

```yaml
resources:
  requests:
    cpu: "100m"      # 0.1 CPU cores (10%)
    memory: "128Mi"  # 128 megabytes
  limits:
    cpu: "500m"      # 0.5 CPU cores (50%)
    memory: "512Mi"  # 512 megabytes
```

#### Requests vs Limits

| Type | Purpose | What Happens if Exceeded |
|------|---------|--------------------------|
| **Requests** | Guaranteed resources | N/A - always guaranteed |
| **Limits** | Maximum allowed | CPU: throttled, Memory: killed (OOMKilled) |

#### CPU Resources

**CPU is measured in "millicores" (m):**
- `1000m` = 1 full CPU core
- `500m` = 0.5 cores (50%)
- `100m` = 0.1 cores (10%)

**What happens when CPU limit is exceeded?**
- Container is **throttled** (slowed down)
- Process continues running, just slower
- Not killed, just less responsive

**Example:**
```
Your pod has CPU limit of 500m (0.5 cores)
Sudden traffic spike causes pod to need 800m
Kubernetes throttles the pod to use only 500m
Response times increase, but pod keeps running
Traffic normalizes, throttling stops
```

#### Memory Resources

**Memory is measured in bytes:**
- `Mi` = Mebibytes (1 Mi = 1,048,576 bytes)
- `Gi` = Gibibytes (1 Gi = 1,073,741,824 bytes)

**What happens when memory limit is exceeded?**
- Container is **killed** (OOMKilled = Out Of Memory Killed)
- Kubernetes automatically restarts the pod
- Application loses all in-memory state

**Example:**
```
Your pod has memory limit of 512Mi
Memory leak causes memory to grow to 513Mi
Kubernetes kills the pod immediately
Pod is restarted with fresh memory
Application starts from clean state
```

#### Why Resource Limits Matter

**Without limits:**
```
Bad pod consumes 16GB of memory
Other pods can't get resources
Node runs out of memory
Node crashes, taking all pods with it
Entire cluster could be affected
```

**With limits:**
```
Bad pod tries to consume 16GB
Hits 512Mi limit and is killed
Only that one pod is affected
Other pods continue running normally
Problem is isolated and auto-healed
```

#### Choosing the Right Values

**Too small:**
- Pods are frequently killed (OOM)
- CPU throttling causes slow responses
- Poor user experience

**Too large:**
- Wasted cluster resources
- Higher infrastructure costs
- Fewer pods can fit on nodes

**How to find the right values:**
1. Start with reasonable estimates (like we did: 100m CPU, 128Mi RAM)
2. Deploy to production
3. Monitor actual usage with Prometheus (Phase 7!)
4. Adjust based on real data
5. Add 20-30% buffer for traffic spikes

---

### Part 6: The Service - Internal Networking and Load Balancing

#### What is a Kubernetes Service?

A **Service** is an abstraction that provides:
- Stable DNS name for accessing pods
- Load balancing across multiple pods
- Service discovery (automatic pod detection)
- Health-based routing (only to ready pods)

**Why we need it:**
- Pods have ephemeral IP addresses that change
- Running multiple replicas needs load balancing
- Other services need a stable way to connect

#### Service Configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "wiki-chart.fullname" . }}-fastapi
spec:
  type: ClusterIP
  ports:
  - port: 8000
    targetPort: 8000
    protocol: TCP
    name: http
  selector:
    app.kubernetes.io/component: api
```

#### Service Type: ClusterIP

**ClusterIP** = Internal cluster networking only

**What you get:**
- Virtual IP address within the cluster (e.g., 10.96.0.20)
- DNS name (e.g., wiki-chart-fastapi)
- Accessible from any pod in the cluster
- NOT accessible from outside the cluster

**Why ClusterIP for FastAPI?**
- External access will come through Ingress (Phase 8)
- More secure (no direct external access)
- Better HTTP routing (path-based, host-based)
- SSL/TLS termination at Ingress level

**Other service types (we're not using):**
- **NodePort**: Exposes service on each node's IP at a static port (30000-32767)
- **LoadBalancer**: Provisions cloud load balancer (costs money, uses cloud IPs)

#### Port Configuration

```yaml
ports:
- port: 8000          # Service listens on this port
  targetPort: 8000    # Forward to this port on the pod
  protocol: TCP
  name: http
```

**Traffic flow:**
```
Request to Service → service-ip:8000 → pod-ip:8000
```

**Example:**
```bash
# Inside another pod in the cluster
curl http://wiki-chart-fastapi:8000/health
# DNS resolves to ClusterIP (10.96.0.20)
# Service forwards to one of the FastAPI pods
# Pod responds
```

#### Selectors - Connecting Service to Pods

```yaml
selector:
  {{- include "wiki-chart.selectorLabels" . | nindent 4 }}
  app.kubernetes.io/component: api
```

**How this works:**

1. Service watches for pods with matching labels
2. When a new pod with these labels starts, Service adds it to endpoints
3. When a pod is deleted, Service removes it from endpoints
4. Readiness probes determine which pods are "healthy" (eligible for traffic)

**Example with 2 replicas:**
```
Service Endpoints:
- 10.1.2.10:8000 (Pod 1 - Ready)
- 10.1.2.11:8000 (Pod 2 - Ready)

Pod 2 fails readiness check
Service Endpoints:
- 10.1.2.10:8000 (Pod 1 - Ready)
  (Pod 2 removed, no traffic sent)

Pod 2 recovers
Service Endpoints:
- 10.1.2.10:8000 (Pod 1 - Ready)
- 10.1.2.11:8000 (Pod 2 - Ready)
```

#### Load Balancing

By default, Kubernetes uses **random** load balancing:
- Each request is sent to a random healthy pod
- Simple and works well for stateless applications
- No consideration of pod load (assumes all pods are equal)

**Session affinity (optional):**
```yaml
sessionAffinity: ClientIP
sessionAffinityConfig:
  clientIP:
    timeoutSeconds: 10800  # 3 hours
```
This makes requests from the same client IP go to the same pod (sticky sessions).

---

## How Values from values.yaml Are Templated

Helm uses Go templating to dynamically insert values from `values.yaml` into manifests.

### Basic Syntax

```yaml
# In values.yaml
fastapi:
  replicaCount: 2
  image:
    repository: wiki-service
    tag: latest

# In template
replicas: {{ .Values.fastapi.replicaCount }}
image: "{{ .Values.fastapi.image.repository }}:{{ .Values.fastapi.image.tag }}"

# After rendering
replicas: 2
image: "wiki-service:latest"
```

### Template Functions

```yaml
# Include named templates
name: {{ include "wiki-chart.fullname" . }}-fastapi

# Indent YAML
labels:
  {{- include "wiki-chart.labels" . | nindent 4 }}

# Conditionals
{{- if .Values.fastapi.enabled }}
  # Only included if fastapi.enabled is true
{{- end }}
```

### Values We Use

| Template Reference | values.yaml Location | Default Value |
|-------------------|---------------------|---------------|
| `.Values.fastapi.replicaCount` | `fastapi.replicaCount` | 2 |
| `.Values.fastapi.image.repository` | `fastapi.image.repository` | wiki-service |
| `.Values.fastapi.image.tag` | `fastapi.image.tag` | latest |
| `.Values.postgresql.database.name` | `postgresql.database.name` | wikidb |
| `.Values.postgresql.database.user` | `postgresql.database.user` | postgres |

### Overriding Values

**During installation:**
```bash
helm install wiki-chart ./wiki-chart \
  --set fastapi.replicaCount=3 \
  --set postgresql.database.password=secret123
```

**Using custom values file:**
```bash
helm install wiki-chart ./wiki-chart \
  -f custom-values.yaml
```

---

## Complete Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                     │
│                                                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │ FastAPI Deployment (2 replicas)                 │   │
│  │                                                  │   │
│  │  ┌────────────────┐    ┌────────────────┐     │   │
│  │  │ FastAPI Pod 1  │    │ FastAPI Pod 2  │     │   │
│  │  │                │    │                │     │   │
│  │  │ Init: wait-for │    │ Init: wait-for │     │   │
│  │  │   postgres ✓   │    │   postgres ✓   │     │   │
│  │  │                │    │                │     │   │
│  │  │ Main:          │    │ Main:          │     │   │
│  │  │  FastAPI:8000  │    │  FastAPI:8000  │     │   │
│  │  │  ENV: DB_*     │    │  ENV: DB_*     │     │   │
│  │  │  Probes: ✓     │    │  Probes: ✓     │     │   │
│  │  │  Resources: ✓  │    │  Resources: ✓  │     │   │
│  │  └────────────────┘    └────────────────┘     │   │
│  │         ↓                       ↓               │   │
│  └─────────┼───────────────────────┼───────────────┘   │
│            │                       │                    │
│  ┌─────────┴───────────────────────┴──────────────┐   │
│  │  FastAPI Service (ClusterIP)                   │   │
│  │  DNS: wiki-chart-fastapi                       │   │
│  │  Port: 8000 → targetPort: 8000                 │   │
│  │  Load balances across healthy pods              │   │
│  └─────────────────────┬────────────────────────────┘   │
│                        │                                │
│                        │ Uses DB_HOST                   │
│                        ↓                                │
│  ┌──────────────────────────────────────────────────┐  │
│  │  PostgreSQL Service (ClusterIP)                  │  │
│  │  DNS: wiki-chart-postgresql                      │  │
│  │  Port: 5432                                      │  │
│  └────────────────┬─────────────────────────────────┘  │
│                   │                                     │
│                   ↓                                     │
│  ┌──────────────────────────────────────────────────┐  │
│  │  PostgreSQL Pod                                   │  │
│  │  - Port: 5432                                     │  │
│  │  - PVC: postgresql-storage (1Gi)                 │  │
│  │  - Data: /var/lib/postgresql/data                │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Testing the Deployment

### Step 1: Validate Templates

```bash
# Render templates locally (doesn't deploy)
helm template wiki-chart ./wiki-chart

# Check for syntax errors
helm lint ./wiki-chart
```

### Step 2: Deploy to Kubernetes

```bash
# Install the chart
helm install wiki-chart ./wiki-chart

# Watch pods start up
kubectl get pods -w

# You should see:
# wiki-chart-fastapi-xxxxx     0/1     Init:0/1   0          5s   (init container running)
# wiki-chart-fastapi-xxxxx     0/1     PodInitializing   0   10s   (init complete)
# wiki-chart-fastapi-xxxxx     1/1     Running           0   15s   (main container running)
```

### Step 3: Check Pod Details

```bash
# Describe the pod
kubectl describe pod wiki-chart-fastapi-xxxxx

# Look for:
# - Init Container exit code (should be 0)
# - Container state (should be Running)
# - Readiness probe status (should be Ready)
# - Events (should show successful start)
```

### Step 4: View Logs

```bash
# Init container logs
kubectl logs wiki-chart-fastapi-xxxxx -c wait-for-postgres

# Should show:
# Waiting for PostgreSQL to be ready...
# PostgreSQL is ready!

# Main container logs
kubectl logs wiki-chart-fastapi-xxxxx -c fastapi

# Should show uvicorn starting FastAPI
```

### Step 5: Test Health Endpoint

```bash
# Port forward to access locally
kubectl port-forward service/wiki-chart-fastapi 8000:8000

# In another terminal
curl http://localhost:8000/health

# Should return:
# {"status":"healthy","timestamp":"2024-01-31T12:00:00"}
```

### Step 6: Check Service Endpoints

```bash
# See which pods the service is routing to
kubectl get endpoints wiki-chart-fastapi

# Should show:
# NAME                 ENDPOINTS
# wiki-chart-fastapi   10.1.2.10:8000,10.1.2.11:8000
```

---

## Troubleshooting

### Init Container Stuck

**Symptom:**
```bash
kubectl get pods
# wiki-chart-fastapi-xxxxx   0/1   Init:0/1   0   2m
```

**Diagnosis:**
```bash
kubectl logs wiki-chart-fastapi-xxxxx -c wait-for-postgres
# Waiting for PostgreSQL to be ready...
# PostgreSQL is unavailable - sleeping
# (repeating)
```

**Possible causes:**
1. PostgreSQL pod not running
2. PostgreSQL service not created
3. PostgreSQL not accepting connections yet

**Solution:**
```bash
# Check PostgreSQL pod
kubectl get pods | grep postgresql

# Check PostgreSQL service
kubectl get svc | grep postgresql

# Wait for PostgreSQL to be fully ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=database --timeout=5m
```

### Pod CrashLoopBackOff

**Symptom:**
```bash
kubectl get pods
# wiki-chart-fastapi-xxxxx   0/1   CrashLoopBackOff   5   10m
```

**Diagnosis:**
```bash
kubectl logs wiki-chart-fastapi-xxxxx --previous
# Check logs from previous (crashed) container
```

**Possible causes:**
1. Wrong environment variables (database connection fails)
2. Database not accessible (network issue)
3. Application bug

**Solution:**
```bash
# Verify environment variables
kubectl exec wiki-chart-fastapi-xxxxx -- env | grep DB_

# Test database connectivity from pod
kubectl exec wiki-chart-fastapi-xxxxx -- nc -zv wiki-chart-postgresql 5432
```

### Readiness Probe Failing

**Symptom:**
```bash
kubectl get pods
# wiki-chart-fastapi-xxxxx   0/1   Running   0   2m
# (Pod running but not Ready)
```

**Diagnosis:**
```bash
kubectl describe pod wiki-chart-fastapi-xxxxx
# Look at Events section:
# Readiness probe failed: Get "http://10.1.2.10:8000/health": dial tcp timeout
```

**Possible causes:**
1. Health endpoint not responding
2. Application still starting up
3. Database connection failing

**Solution:**
```bash
# Check application logs
kubectl logs wiki-chart-fastapi-xxxxx

# Exec into pod and test locally
kubectl exec -it wiki-chart-fastapi-xxxxx -- sh
curl localhost:8000/health
```

---

## Next Steps: Phase 7 - Prometheus Monitoring

Now that FastAPI is deployed, we need to monitor it!

**Phase 7 will cover:**

1. **Prometheus Deployment**
   - Time-series database for metrics
   - Scrapes `/metrics` endpoint from FastAPI
   - Stores performance data

2. **Prometheus Configuration**
   - Scrape configuration
   - ServiceMonitor for automatic discovery
   - Retention policies

3. **Metrics We'll Collect**
   - Request rates (requests per second)
   - Response times (latency percentiles)
   - Error rates (4xx, 5xx responses)
   - Resource usage (CPU, memory)

4. **Grafana Setup** (Phase 8)
   - Visualization dashboards
   - Real-time graphs
   - Alerting rules

**Why monitoring matters:**
- Detect issues before users notice
- Understand application performance
- Make data-driven scaling decisions
- Debug production problems

---

## Summary

In Phase 6, we created:

✅ **fastapi-deployment.yaml**
- Manages FastAPI application pods
- Init container ensures PostgreSQL is ready
- Environment variables connect to database
- Health probes enable self-healing
- Resource limits prevent cluster issues

✅ **fastapi-service.yaml**
- Provides stable internal networking
- Load balances across multiple pods
- Enables service discovery via DNS
- Routes traffic only to healthy pods

✅ **Key Concepts Learned**
- Deployments for stateless applications
- Init containers for dependency management
- Environment variables for configuration
- Liveness vs readiness probes
- Resource requests and limits
- Kubernetes Services and load balancing
- Helm templating with values.yaml

**Our application is now:**
- ✅ Running in Kubernetes
- ✅ Connected to PostgreSQL
- ✅ Highly available (2 replicas)
- ✅ Self-healing (automatic restarts)
- ✅ Load balanced
- ✅ Ready for monitoring

**Next:** Phase 7 - Deploy Prometheus for metrics collection! 📊
