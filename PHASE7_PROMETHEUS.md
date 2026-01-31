# Phase 7: Prometheus Monitoring Deployment

## Overview

In Phase 7, we deploy Prometheus to monitor our FastAPI application and collect metrics over time. This phase establishes the observability foundation that will enable Grafana dashboards in Phase 8.

**What we're deploying:**
- Prometheus server (time-series database and scraper)
- Persistent storage for metrics data (15-day retention)
- Automatic metric collection from FastAPI `/metrics` endpoint
- Self-monitoring (Prometheus monitoring itself)

**Why monitoring matters:**
- Understand application behavior and performance
- Detect issues before they become critical
- Track trends over time (traffic patterns, error rates)
- Make data-driven scaling decisions
- Debug production problems with historical data

---

## Files Created

### 1. `prometheus-configmap.yaml`
Defines what endpoints Prometheus should scrape and how often to collect metrics.

### 2. `prometheus-pvc.yaml`
Requests persistent storage to keep metrics data across pod restarts.

### 3. `prometheus-deployment.yaml`
Manages the Prometheus server pod with health probes and resource limits.

### 4. `prometheus-service.yaml`
Provides stable internal networking for Grafana (Phase 8) to query metrics.

### 5. Enhanced `wiki-service/app/main.py`
Added `/health` endpoint for Kubernetes health checks.

---

## What is Prometheus?

### The Monitoring Problem

Imagine you're running a restaurant (your FastAPI application). You need to know:
- How many customers visit per hour? (requests per second)
- How long do they wait for food? (response times)
- Are any orders failing? (error rates)
- Is the kitchen running out of ingredients? (resource usage)

Without monitoring, you're **flying blind** - you only know there's a problem when customers complain.

### Prometheus Solution

**Prometheus** is an open-source monitoring system that:
1. **Collects metrics** by scraping HTTP endpoints (e.g., `/metrics`)
2. **Stores time-series data** in an efficient database (TSDB)
3. **Allows queries** using PromQL (Prometheus Query Language)
4. **Provides a web UI** for exploring metrics and debugging

### Key Concepts

#### 1. Time-Series Data

A **time series** is a sequence of data points indexed by time.

**Example:**
```
Metric: users_created_total
Value at 10:00 AM: 42
Value at 10:15 AM: 45
Value at 10:30 AM: 51
Value at 10:45 AM: 55
```

This creates a series: `[(10:00, 42), (10:15, 45), (10:30, 51), (10:45, 55)]`

You can now:
- **Visualize**: Plot a graph showing user creation trend
- **Analyze**: Calculate rate of user creation (13 users per hour)
- **Alert**: Trigger alert if no users created in 1 hour

#### 2. Metrics Types

| Type | Description | Example | Use Case |
|------|-------------|---------|----------|
| **Counter** | Monotonically increasing value | `users_created_total` | Counts events (never decreases) |
| **Gauge** | Value that can go up or down | `memory_usage_bytes` | Current state (memory, CPU, connections) |
| **Histogram** | Distribution of values | `request_duration_seconds` | Response times, request sizes |
| **Summary** | Similar to histogram (client-side) | `request_duration_summary` | Quantiles (p50, p95, p99) |

**Our application uses Counters:**
```python
from prometheus_client import Counter

users_created_total = Counter('users_created_total', 'Total users created')
posts_created_total = Counter('posts_created_total', 'Total posts created')

# When user is created:
users_created_total.inc()  # Increment counter
```

#### 3. Pull-Based Architecture

**Prometheus uses a "pull" model** (not "push"):

```
Traditional Push Model:
Application → (push metrics) → Monitoring System

Prometheus Pull Model:
Prometheus → (scrape /metrics) → Application
```

**Why pull?**
- **Centralized control**: Prometheus decides when to scrape
- **Service discovery**: Prometheus finds targets automatically
- **Health monitoring**: Failed scrape = target is down
- **Easier debugging**: You can curl the `/metrics` endpoint yourself

#### 4. Labels

**Labels** add dimensions to metrics for filtering and grouping.

**Example:**
```
http_requests_total{method="GET", path="/users", status="200"} 1523
http_requests_total{method="POST", path="/users", status="201"} 42
http_requests_total{method="GET", path="/users", status="404"} 7
```

You can now query:
- Total requests: `sum(http_requests_total)`
- GET requests only: `http_requests_total{method="GET"}`
- Error rate: `http_requests_total{status=~"5.."}`

---

## Detailed Component Explanation

### Part 1: ConfigMap - Defining What to Monitor

#### What is a ConfigMap?

A **ConfigMap** stores configuration data as key-value pairs. Think of it as a configuration file stored in Kubernetes.

**Why use ConfigMap instead of embedding config in the image?**
- **Separation of concerns**: Config separate from code
- **Easy updates**: Change config without rebuilding image
- **Environment-specific**: Different config for dev/staging/prod
- **Version control**: Config changes tracked in Git

#### Our Prometheus Configuration

The ConfigMap contains `prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'fastapi'
    static_configs:
      - targets: ['wiki-chart-fastapi:8000']
    metrics_path: '/metrics'
  
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

#### Global Settings

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
```

**`scrape_interval: 15s`**
- How often to collect metrics from targets
- 15 seconds = 4 times per minute = 240 times per hour
- **Trade-offs:**
  - Lower (e.g., 5s): More current data, higher resource usage
  - Higher (e.g., 60s): Less resource usage, less granular data

**`evaluation_interval: 15s`**
- How often to evaluate recording and alerting rules
- We don't have rules yet, but this prepares for Phase 10+
- Should match or be a multiple of scrape_interval

#### Scrape Configuration 1: FastAPI

```yaml
- job_name: 'fastapi'
  static_configs:
    - targets: ['wiki-chart-fastapi:8000']
  metrics_path: '/metrics'
```

**Breaking it down:**

1. **`job_name: 'fastapi'`**
   - Logical name for this scrape target
   - Automatically added as label: `job="fastapi"`
   - Used to filter metrics: `users_created_total{job="fastapi"}`

2. **`static_configs`**
   - Manually specify target addresses
   - Alternative: `kubernetes_sd_configs` for automatic service discovery
   - Static is simpler for this project

3. **`targets: ['wiki-chart-fastapi:8000']`**
   - Kubernetes service DNS name: `wiki-chart-fastapi`
   - Port: `8000` (FastAPI service port)
   - Full URL scraped: `http://wiki-chart-fastapi:8000/metrics`

4. **`metrics_path: '/metrics'`**
   - HTTP endpoint where metrics are exposed
   - Default is `/metrics`, but can be anything
   - FastAPI application exposes metrics here

#### What Gets Scraped?

When Prometheus scrapes `http://wiki-chart-fastapi:8000/metrics`, it gets:

```
# HELP users_created_total Total users created
# TYPE users_created_total counter
users_created_total 42.0

# HELP posts_created_total Total posts created
# TYPE posts_created_total counter
posts_created_total 17.0

# HELP python_gc_objects_collected_total Objects collected during gc
# TYPE python_gc_objects_collected_total counter
python_gc_objects_collected_total{generation="0"} 523.0
python_gc_objects_collected_total{generation="1"} 45.0
python_gc_objects_collected_total{generation="2"} 3.0

# Plus ~40 more Python runtime metrics...
```

#### Scrape Configuration 2: Self-Monitoring

```yaml
- job_name: 'prometheus'
  static_configs:
    - targets: ['localhost:9090']
```

**Why monitor Prometheus itself?**
- Ensure the monitoring system is healthy
- Track metrics about metric collection (meta!)
- Monitor TSDB performance and storage

**What gets collected:**
```
prometheus_tsdb_storage_blocks_bytes  # Storage used
prometheus_http_requests_total        # API requests
prometheus_rule_evaluations_total     # Rule evaluations
prometheus_target_scrape_duration_seconds  # Scrape performance
```

**Example use case:**
If Prometheus scraping becomes slow, you'll see it in `prometheus_target_scrape_duration_seconds` and can investigate.

---

### Part 2: PersistentVolumeClaim - Storing Metrics Data

#### What is Persistent Storage?

**Without PVC:**
```
1. Prometheus starts and collects metrics
2. Data stored in container filesystem
3. Pod restarts (update, crash, node failure)
4. All metrics lost! 📉
5. No historical data for analysis
```

**With PVC:**
```
1. Prometheus starts and collects metrics
2. Data stored on persistent volume
3. Pod restarts
4. New pod mounts same volume
5. All historical data still available! 📈
```

#### Why Prometheus Needs Persistent Storage

Prometheus is a **stateful application** - it stores time-series data in a local database (TSDB). Losing this data means:
- No historical metrics (can't see trends)
- No data for dashboards (Grafana would be empty)
- Can't debug past incidents
- Lose context of what's "normal" behavior

#### TSDB Architecture

Prometheus uses a **Time Series Database** optimized for:

**1. Write Performance**
- Handles thousands of writes per second
- Append-only writes (never updates old data)
- Efficient compression (saves disk space)

**2. Query Performance**
- Fast range queries: "Get all metrics from last hour"
- Efficient filtering by labels
- Aggregation optimizations

**3. Disk Layout**
```
/prometheus/
├── 01HQXX...XX/  # Block 1 (2-hour chunk)
│   ├── chunks/   # Compressed time series data
│   ├── index     # Index for fast lookups
│   └── meta.json # Block metadata
├── 01HQXY...XY/  # Block 2 (2-hour chunk)
├── wal/          # Write-Ahead Log (crash recovery)
└── lock          # Lock file (prevents concurrent access)
```

#### Storage Requirements

**How much storage do we need?**

Our configuration:
- **Scrape interval**: 15 seconds (4 times per minute)
- **Metrics per scrape**: ~50 metrics from FastAPI
- **Retention**: 15 days

**Calculation:**
```
Data points per day:
50 metrics × 4 scrapes/min × 60 min/hour × 24 hours = 288,000 points/day

Storage per day (compressed):
288,000 points × ~0.2 bytes/point = ~50 MB/day

15-day retention:
50 MB/day × 15 days = 750 MB

Add buffer for growth and WAL:
750 MB × 2 = 1.5 GB → round to 2 GB
```

**Result**: 2Gi PVC is sufficient for our use case.

#### PVC Configuration Explained

```yaml
accessModes:
  - ReadWriteOnce
```

**ReadWriteOnce (RWO)** means:
- Volume can be mounted by **one node** at a time
- That node can read and write
- Perfect for Prometheus (single replica only)

**Other access modes (for reference):**
- **ReadOnlyMany (ROX)**: Multiple nodes can read, none can write
- **ReadWriteMany (RWX)**: Multiple nodes can read and write (rare, expensive)

**Why RWO for Prometheus?**
Prometheus TSDB doesn't support multiple writers. Running multiple Prometheus instances writing to the same storage would **corrupt the database**. For high availability, use Prometheus Federation or Thanos (advanced topics).

```yaml
storageClassName: standard
```

**Storage Class** determines the type of disk:

| Storage Class | Backend | Characteristics |
|---------------|---------|-----------------|
| `standard` | Default provisioner | Varies by platform (hostpath, EBS, etc.) |
| `fast` or `ssd` | SSD-backed storage | Higher performance, higher cost |
| `slow` or `hdd` | HDD-backed storage | Lower performance, lower cost |

For development, `standard` is fine. For production with high metric cardinality, consider SSD storage.

```yaml
resources:
  requests:
    storage: 2Gi
```

**Storage request**: Minimum storage guaranteed by the volume.

**What happens if you run out of space?**
- Prometheus stops ingesting new metrics
- Logs error: "not enough disk space"
- Existing data preserved (no corruption)
- Resolution: Increase PVC size or reduce retention time

---

### Part 3: Deployment - Running Prometheus

#### Single Replica Architecture

```yaml
replicas: 1
```

**Why only 1 replica?**

Prometheus TSDB is designed for single-writer scenarios:
- Multiple Prometheus instances writing to the same PVC would **corrupt data**
- Each block has a lock file preventing concurrent writes
- Local storage model (not distributed)

**High availability options (advanced):**
1. **Prometheus Federation**: Multiple Prometheus, one aggregates data
2. **Thanos**: Distributed Prometheus with object storage backend
3. **Cortex**: Multi-tenant, horizontally scalable Prometheus

For this project, single replica provides:
- Simplicity and ease of understanding
- Sufficient reliability for development/learning
- Foundation for later HA implementation

#### Container Configuration

```yaml
image: prom/prometheus:v2.48.0
```

**Version `v2.48.0`** is a stable LTS (Long-Term Support) release:
- Battle-tested in production
- Security patches maintained
- Extensive documentation
- Broad ecosystem compatibility

#### Prometheus Command-Line Arguments

```yaml
args:
  - '--config.file=/etc/prometheus/prometheus.yml'
  - '--storage.tsdb.path=/prometheus'
  - '--storage.tsdb.retention.time=15d'
  - '--web.enable-lifecycle'
  - '--web.console.libraries=/etc/prometheus/console_libraries'
  - '--web.console.templates=/etc/prometheus/consoles'
```

**Breaking down each argument:**

**1. `--config.file=/etc/prometheus/prometheus.yml`**
- Path to main configuration file
- Mounted from ConfigMap
- Defines scrape targets and global settings

**2. `--storage.tsdb.path=/prometheus`**
- Directory for TSDB data
- Mounted from PVC (persistent storage)
- Contains blocks, WAL, and index

**3. `--storage.tsdb.retention.time=15d`**
- Keep metrics for 15 days
- Older data automatically deleted
- Configurable based on storage and requirements

**Why 15 days?**
- Enough for weekly trend analysis
- Reasonable storage requirement (750MB)
- Longer retention requires more storage

**Example retention strategies:**
```
Development: 7d (saves storage, faster testing)
Production: 30d (monthly reports, incident investigation)
Long-term: Use remote storage (Thanos, Cortex) for unlimited retention
```

**4. `--web.enable-lifecycle`**
- Enables HTTP reload endpoint: `POST /-/reload`
- Allows config reload without pod restart
- Useful for config changes

**Example usage:**
```bash
# Update ConfigMap
kubectl apply -f prometheus-configmap.yaml

# Reload Prometheus config (no restart needed)
kubectl exec -it wiki-chart-prometheus-xxx -- \
  curl -X POST http://localhost:9090/-/reload
```

**5. `--web.console.libraries` and `--web.console.templates`**
- Enable Prometheus web UI console templates
- Provides pre-built dashboards
- Not commonly used (Grafana preferred), but included for completeness

#### Health Probes

**Liveness Probe:**
```yaml
livenessProbe:
  httpGet:
    path: /-/healthy
    port: 9090
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
```

**Endpoint: `/-/healthy`**
- Returns `200 OK` if Prometheus process is running
- Returns `503 Service Unavailable` if not healthy

**What it checks:**
- Process is alive and responding
- Not checking TSDB corruption or scrape failures
- Basic health check only

**When would it fail and trigger restart?**
- Prometheus process crashes
- Web server deadlocks
- Out of memory (before OOMKill)

**Readiness Probe:**
```yaml
readinessProbe:
  httpGet:
    path: /-/ready
    port: 9090
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3
```

**Endpoint: `/-/ready`**
- Returns `200 OK` if Prometheus is ready to serve queries
- Returns `503 Service Unavailable` if not ready

**What it checks:**
- Configuration loaded successfully
- TSDB initialized
- Scrape loops started
- Ready to serve queries

**When would it fail?**
- Startup phase (first 10 seconds)
- Config reload in progress
- TSDB corruption detected

**Liveness vs Readiness:**

| Scenario | Liveness | Readiness | Result |
|----------|----------|-----------|--------|
| Prometheus starting up | ✅ Healthy | ❌ Not ready | No traffic, no restart |
| Prometheus fully running | ✅ Healthy | ✅ Ready | Receiving traffic |
| Config reload | ✅ Healthy | ❌ Not ready | Briefly no traffic |
| Process crashed | ❌ Not healthy | ❌ Not ready | Pod restarted |

#### Volume Mounts

```yaml
volumeMounts:
- name: config
  mountPath: /etc/prometheus
  readOnly: true

- name: storage
  mountPath: /prometheus
```

**Mount 1: Configuration (ConfigMap)**
```yaml
- name: config
  mountPath: /etc/prometheus
  readOnly: true
```

**What gets mounted:**
- ConfigMap `prometheus-config` → `/etc/prometheus/`
- File: `prometheus.yml` → `/etc/prometheus/prometheus.yml`
- **Read-only**: Config shouldn't be modified at runtime

**Why mount as directory instead of single file?**
- Future: Add additional config files (alerts, rules)
- Cleaner than multiple volume mounts
- Standard Prometheus convention

**Mount 2: Data Storage (PVC)**
```yaml
- name: storage
  mountPath: /prometheus
```

**What gets mounted:**
- PVC `prometheus-pvc` → `/prometheus/`
- Contains: TSDB blocks, WAL, index
- **Read-write**: Prometheus writes metrics here

**Directory structure after mount:**
```
/prometheus/
├── 01HQXX...XX/      # Block 1 (2-hour time range)
│   ├── chunks/       # Compressed samples
│   │   └── 000001
│   ├── index         # Series and labels index
│   ├── meta.json     # Block metadata
│   └── tombstones    # Deleted series
├── 01HQXY...XY/      # Block 2
├── chunks_head/      # Most recent data (not yet compacted)
│   └── 000001
├── wal/              # Write-Ahead Log (crash recovery)
│   ├── 00000000
│   └── 00000001
├── queries.active    # Currently running queries
└── lock              # Prevents concurrent access
```

#### Resource Limits

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 1Gi
```

**Why these specific values?**

**CPU: 100m request, 500m limit**
- **Baseline (100m)**: Idle Prometheus uses ~50m
- **Scraping**: Each scrape uses ~5-10m for a few seconds
- **Queries**: Complex queries can spike to 200-300m
- **Limit (500m)**: Allows room for query spikes

**Memory: 256Mi request, 1Gi limit**
- **Baseline (256Mi)**: Prometheus core + recent samples
- **TSDB head**: In-memory chunk (last 2 hours) ~200-400Mi
- **Query processing**: Temporary data for aggregations
- **Limit (1Gi)**: Safety buffer for complex queries

**What happens at limits?**

| Resource | At Limit | Behavior |
|----------|----------|----------|
| CPU | Reaches 500m | Throttled (slowed down), not killed |
| Memory | Reaches 1Gi | Killed (OOMKilled), pod restarted |

**Signs you need to increase resources:**
- CPU: Slow scraping, missed scrapes
- Memory: Frequent OOMKills, pod restarts

---

### Part 4: Service - Internal Networking

#### What is the Service For?

The Prometheus Service provides:
1. **Stable DNS name**: `wiki-chart-prometheus.default.svc.cluster.local`
2. **ClusterIP**: Internal IP address (e.g., `10.96.0.42`)
3. **Port mapping**: External port 9090 → Pod port 9090
4. **Load balancing**: (Not used here - single replica)
5. **Health routing**: Only routes to ready pods

#### Service Type: ClusterIP

```yaml
type: ClusterIP
```

**ClusterIP** means:
- Service accessible only **within the cluster**
- Gets a virtual IP (e.g., 10.96.0.42)
- Not accessible from outside

**Who will use this service?**
- **Grafana (Phase 8)**: Queries Prometheus for dashboard data
- **Developers**: Port-forward to access Prometheus UI
- **Future Ingress (Phase 9)**: Exposes Prometheus externally

**Why not NodePort or LoadBalancer?**
- **Security**: Don't expose monitoring to internet
- **Cost**: LoadBalancer costs money in cloud
- **Best practice**: Use Ingress for external access (Phase 9)

#### Port Configuration

```yaml
ports:
- port: 9090
  targetPort: 9090
  protocol: TCP
  name: prometheus
```

**Port mapping:**
```
External (Service)     Internal (Pod)
     9090         →        9090
```

**Terminology:**
- **`port`**: Port on the Service (what clients connect to)
- **`targetPort`**: Port on the Pod (where Prometheus listens)
- **`name`**: Descriptive name for the port (used in Ingress)

**Example connection from Grafana:**
```python
# Grafana configuration
datasource_url = "http://wiki-chart-prometheus:9090"

# What happens:
# 1. Grafana resolves DNS: wiki-chart-prometheus → 10.96.0.42
# 2. Connects to 10.96.0.42:9090
# 3. Service routes to Prometheus pod's port 9090
# 4. Prometheus receives the query
```

#### Selector

```yaml
selector:
  app.kubernetes.io/component: monitoring
```

**How it works:**
1. Service looks for pods with label `app.kubernetes.io/component: monitoring`
2. Finds Prometheus pod (has this label in Deployment)
3. Creates endpoint: `PodIP:9090`
4. Routes traffic to this endpoint

**Verify selector is working:**
```bash
# Check service endpoints
kubectl get endpoints wiki-chart-prometheus

# Output:
# NAME                      ENDPOINTS          AGE
# wiki-chart-prometheus     10.244.0.42:9090   5m
```

If endpoints are empty, selector doesn't match any pods!

---

## How Values Are Templated

All hardcoded values come from `wiki-chart/values.yaml`, making the chart configurable and reusable.

### ConfigMap Templating

```yaml
# In prometheus-configmap.yaml:
scrape_interval: {{ .Values.prometheus.scrapeInterval }}

# From values.yaml:
prometheus:
  scrapeInterval: 15s

# Rendered result:
scrape_interval: 15s
```

**Benefits:**
- Change scrape interval without editing templates
- Different values for dev/staging/prod
- Override via command line: `helm install --set prometheus.scrapeInterval=30s`

### Service Name Templating

```yaml
# In prometheus-configmap.yaml:
targets: ['{{ include "wiki-chart.fullname" . }}-fastapi:{{ .Values.fastapi.service.port }}']

# Renders to:
targets: ['wiki-chart-fastapi:8000']
```

**Why use `include "wiki-chart.fullname"`?**
- Consistent naming across all resources
- Handles release name properly
- Avoids naming conflicts in shared namespaces

### Image Templating

```yaml
# In prometheus-deployment.yaml:
image: "{{ .Values.prometheus.image.repository }}:{{ .Values.prometheus.image.tag }}"

# From values.yaml:
prometheus:
  image:
    repository: prom/prometheus
    tag: v2.48.0

# Rendered result:
image: "prom/prometheus:v2.48.0"
```

**Benefits:**
- Easy version upgrades: Change one line in values.yaml
- Use private registry: Override repository
- Testing: Use different tag for staging

### Resource Templating

```yaml
# In prometheus-deployment.yaml:
resources:
  requests:
    cpu: {{ .Values.prometheus.resources.requests.cpu }}
    memory: {{ .Values.prometheus.resources.requests.memory }}
  limits:
    cpu: {{ .Values.prometheus.resources.limits.cpu }}
    memory: {{ .Values.prometheus.resources.limits.memory }}

# From values.yaml:
prometheus:
  resources:
    requests:
      cpu: "100m"
      memory: "256Mi"
    limits:
      cpu: "500m"
      memory: "1Gi"
```

**Benefits:**
- Adjust resources without editing templates
- Different resource allocation per environment
- Easy to tune based on monitoring data

---

## Testing the Deployment

### Step 1: Validate Helm Templates

```bash
# Check for syntax errors
helm lint ./wiki-chart

# Expected output:
# ==> Linting ./wiki-chart
# [INFO] Chart.yaml: icon is recommended
# 
# 1 chart(s) linted, 0 chart(s) failed
```

**What `helm lint` checks:**
- YAML syntax errors
- Required fields in Chart.yaml
- Template rendering issues
- Values.yaml structure

### Step 2: Render Templates (Dry Run)

```bash
# Render all templates to see final YAML
helm template wiki-chart ./wiki-chart > /tmp/rendered.yaml

# View Prometheus resources
grep -A 30 "kind: ConfigMap" /tmp/rendered.yaml | grep -A 30 "prometheus-config"
grep -A 20 "kind: PersistentVolumeClaim" /tmp/rendered.yaml | grep -A 20 "prometheus-pvc"
grep -A 100 "kind: Deployment" /tmp/rendered.yaml | grep -A 100 "prometheus"
grep -A 20 "kind: Service" /tmp/rendered.yaml | grep -A 20 "prometheus"
```

**What to verify:**
- ConfigMap has correct scrape targets
- PVC requests 2Gi storage
- Deployment has correct image and args
- Service selector matches deployment labels

### Step 3: Deploy to Kubernetes

```bash
# Install or upgrade the Helm chart
helm upgrade --install wiki-chart ./wiki-chart

# Expected output:
# Release "wiki-chart" has been upgraded. Happy Helming!
# NAME: wiki-chart
# LAST DEPLOYED: [timestamp]
# NAMESPACE: default
# STATUS: deployed
# REVISION: 2
```

**What happens during deployment:**
1. Helm renders all templates with values
2. Applies ConfigMap (Prometheus config created)
3. Creates PVC (storage provisioned)
4. Creates Deployment (pod scheduled)
5. Creates Service (ClusterIP assigned)

### Step 4: Verify Prometheus Pod is Running

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/component=monitoring

# Expected output:
# NAME                                   READY   STATUS    RESTARTS   AGE
# wiki-chart-prometheus-5d7f9c8b6-x7k9m   1/1     Running   0          2m
```

**Pod states:**
- `Pending`: Waiting for PVC or node resources
- `ContainerCreating`: Pulling image, mounting volumes
- `Running`: Prometheus is up!
- `CrashLoopBackOff`: Check logs for errors

**If not running:**
```bash
# Describe pod for events
kubectl describe pod -l app.kubernetes.io/component=monitoring

# Check pod logs
kubectl logs -l app.kubernetes.io/component=monitoring
```

### Step 5: Verify PVC is Bound

```bash
# Check PVC status
kubectl get pvc

# Expected output:
# NAME                          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# wiki-chart-prometheus-pvc     Bound    pvc-a1b2c3d4-e5f6-4321-abcd-1234567890ab   2Gi        RWO            standard       2m
```

**PVC states:**
- `Pending`: Waiting for storage provisioner
- `Bound`: Volume created and attached!

**If stuck in Pending:**
```bash
# Check storage classes
kubectl get storageclass

# Describe PVC for events
kubectl describe pvc wiki-chart-prometheus-pvc

# Common issues:
# - No default storage class
# - Storage class doesn't exist
# - No available storage
```

### Step 6: Check Prometheus Logs

```bash
# View Prometheus startup logs
kubectl logs -l app.kubernetes.io/component=monitoring --tail=50

# Expected output should include:
# level=info msg="Starting Prometheus" version="(version=2.48.0)"
# level=info msg="TSDB started"
# level=info msg="Loading configuration file" filename=/etc/prometheus/prometheus.yml
# level=info msg="Completed loading of configuration file"
# level=info msg="Server is ready to receive web requests."
```

**What to look for:**
- ✅ "TSDB started" - Database initialized
- ✅ "Loading configuration file" - Config loaded
- ✅ "Server is ready" - Prometheus is up!
- ❌ "error" or "failed" - Something went wrong

**Common errors:**
```
# Error: Invalid configuration
# Fix: Check prometheus-configmap.yaml syntax

# Error: Permission denied on /prometheus
# Fix: Check PVC mount permissions

# Error: Cannot connect to target
# Fix: Check FastAPI service name and port
```

### Step 7: Access Prometheus UI

```bash
# Port-forward to access Prometheus UI locally
kubectl port-forward svc/wiki-chart-prometheus 9090:9090

# Output:
# Forwarding from 127.0.0.1:9090 -> 9090
# Forwarding from [::1]:9090 -> 9090
```

**Open in browser:** http://localhost:9090

**What you should see:**
- Prometheus web UI
- Navigation: Graph, Alerts, Status, Help

**Note:** Port-forward runs in foreground. Press `Ctrl+C` to stop.

### Step 8: Verify Scrape Targets

**In Prometheus UI:**
1. Click **Status** → **Targets**
2. You should see two targets:

| Endpoint | State | Labels | Last Scrape |
|----------|-------|--------|-------------|
| http://wiki-chart-fastapi:8000/metrics | UP | job="fastapi" | 2s ago |
| http://localhost:9090/metrics | UP | job="prometheus" | 3s ago |

**Target states:**
- **UP** ✅: Prometheus successfully scraping metrics
- **DOWN** ❌: Cannot reach target
- **UNKNOWN** ⚠️: Not scraped yet

**If target is DOWN:**
1. Check FastAPI pods are running: `kubectl get pods -l app.kubernetes.io/component=api`
2. Check FastAPI service exists: `kubectl get svc wiki-chart-fastapi`
3. Test connectivity from Prometheus pod:
   ```bash
   kubectl exec -it wiki-chart-prometheus-xxx -- \
     wget -O- http://wiki-chart-fastapi:8000/metrics
   ```

### Step 9: Query Metrics

**In Prometheus UI:**
1. Click **Graph** tab
2. In the query box, enter: `users_created_total`
3. Click **Execute**

**What you should see:**
- Table showing current value
- Graph showing value over time

**Try these queries:**
```promql
# Total users created
users_created_total

# Total posts created
posts_created_total

# Rate of user creation (per second, 5-minute average)
rate(users_created_total[5m])

# Prometheus self-monitoring: scrape duration
prometheus_target_scrape_duration_seconds

# All Python metrics from FastAPI
{job="fastapi"}
```

### Step 10: Generate Test Traffic

Create some users and posts to see metrics change:

```bash
# Port-forward FastAPI service (in a new terminal)
kubectl port-forward svc/wiki-chart-fastapi 8000:8000

# Create test users (in another terminal)
for i in {1..10}; do
  curl -X POST http://localhost:8000/users \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"TestUser$i\"}"
  echo ""
done

# Create test posts
for i in {1..5}; do
  curl -X POST http://localhost:8000/posts \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": 1, \"content\": \"Test post $i\"}"
  echo ""
done
```

**Back in Prometheus UI:**
1. Wait 15 seconds (next scrape interval)
2. Query: `users_created_total`
3. Should see count increased by 10!
4. Query: `posts_created_total`
5. Should see count increased by 5!

**View rate of creation:**
```promql
# Users created per second (5-minute average)
rate(users_created_total[5m])

# If you created 10 users in 1 minute:
# rate ≈ 10 users / 60 seconds ≈ 0.167 users/second
```

---

## Troubleshooting

### Issue 1: Prometheus Pod Not Starting

**Symptoms:**
```bash
kubectl get pods -l app.kubernetes.io/component=monitoring
# NAME                      READY   STATUS             RESTARTS   AGE
# wiki-chart-prometheus-xxx   0/1     CrashLoopBackOff   5          10m
```

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod wiki-chart-prometheus-xxx

# Check pod logs
kubectl logs wiki-chart-prometheus-xxx
```

**Common causes and fixes:**

**A. Invalid configuration:**
```
Error: error loading config from "/etc/prometheus/prometheus.yml": yaml: line 10: could not find expected ':'
```
**Fix:** Check `prometheus-configmap.yaml` for YAML syntax errors

**B. Permission denied:**
```
Error: opening storage failed: mkdir /prometheus: permission denied
```
**Fix:** Add security context to deployment (uncomment securityContext section)

**C. Insufficient memory:**
```
Error: (killed by OOMKiller)
```
**Fix:** Increase memory limits in values.yaml:
```yaml
prometheus:
  resources:
    limits:
      memory: "2Gi"  # Increased from 1Gi
```

### Issue 2: PVC Stuck in Pending

**Symptoms:**
```bash
kubectl get pvc
# NAME                       STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# wiki-chart-prometheus-pvc  Pending                                      standard       5m
```

**Diagnosis:**
```bash
kubectl describe pvc wiki-chart-prometheus-pvc
```

**Common causes and fixes:**

**A. No default StorageClass:**
```
Events:
  Warning  ProvisioningFailed  no volume plugin matched
```
**Fix:** Check available storage classes and set one as default:
```bash
# List storage classes
kubectl get storageclass

# If none exist, you might be on Minikube
# Start with storage addons:
minikube addons enable storage-provisioner
minikube addons enable default-storageclass
```

**B. StorageClass doesn't exist:**
```
Events:
  Warning  ProvisioningFailed  storageclass.storage.k8s.io "standard" not found
```
**Fix:** Use an existing storage class in values.yaml:
```yaml
prometheus:
  persistence:
    storageClass: "hostpath"  # or whatever is available
```

**C. Insufficient storage:**
```
Events:
  Warning  ProvisioningFailed  insufficient storage
```
**Fix:** Free up storage or reduce PVC size in values.yaml:
```yaml
prometheus:
  persistence:
    size: 1Gi  # Reduced from 2Gi
```

### Issue 3: FastAPI Target is DOWN

**Symptoms:**
In Prometheus UI (Status → Targets):
```
Target: http://wiki-chart-fastapi:8000/metrics
State: DOWN (Connection refused)
```

**Diagnosis:**
```bash
# 1. Check if FastAPI pods are running
kubectl get pods -l app.kubernetes.io/component=api

# 2. Check if FastAPI service exists
kubectl get svc wiki-chart-fastapi

# 3. Test connectivity from Prometheus pod
kubectl exec -it wiki-chart-prometheus-xxx -- \
  wget -O- http://wiki-chart-fastapi:8000/metrics
```

**Common causes and fixes:**

**A. FastAPI pods not running:**
```bash
kubectl get pods -l app.kubernetes.io/component=api
# No resources found
```
**Fix:** FastAPI deployment might not be deployed yet. Deploy it:
```bash
helm upgrade --install wiki-chart ./wiki-chart
```

**B. Service name mismatch:**
```bash
kubectl get svc
# NAME                         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
# wiki-chart-fastapi-service   ClusterIP   10.96.50.179   <none>        8000/TCP   1h
```
Service name is `wiki-chart-fastapi-service`, not `wiki-chart-fastapi`!

**Fix:** Check service name and update ConfigMap if needed.

**C. FastAPI /metrics endpoint not working:**
```bash
# Test directly from FastAPI pod
kubectl exec -it wiki-chart-fastapi-xxx -- \
  curl http://localhost:8000/metrics

# If 404 or error, check FastAPI logs
kubectl logs wiki-chart-fastapi-xxx
```

### Issue 4: Metrics Not Updating

**Symptoms:**
- Prometheus UI shows old metrics
- Counter values not increasing
- Last scrape timestamp is old

**Diagnosis:**
```bash
# Check Prometheus is scraping
# In Prometheus UI, query:
up{job="fastapi"}

# If value is 0, target is down
# If value is 1, target is up but might have other issues
```

**Common causes and fixes:**

**A. Scrape interval too long:**
Default 15 seconds might feel slow during testing.

**Workaround:** Generate traffic and wait a bit longer, or reduce scrape interval:
```yaml
# values.yaml
prometheus:
  scrapeInterval: 5s  # Reduced from 15s (use for testing only)
```

**B. Browser caching:**
Prometheus UI might cache query results.

**Fix:** Hard refresh browser (`Ctrl+Shift+R`) or append timestamp to query:
```promql
users_created_total[1m]
```

**C. Prometheus not writing to disk:**
```bash
# Check TSDB status in Prometheus UI
# Status → TSDB Status
# Look for errors or warnings
```

### Issue 5: High Memory Usage

**Symptoms:**
```bash
kubectl top pod wiki-chart-prometheus-xxx
# NAME                      CPU(cores)   MEMORY(bytes)
# wiki-chart-prometheus-xxx  150m         950Mi
```
Memory is close to the 1Gi limit!

**Diagnosis:**
```bash
# In Prometheus UI, query:
prometheus_tsdb_head_samples
# This shows how many samples are in memory

prometheus_tsdb_head_chunks
# Number of chunks in memory
```

**Solutions:**

**A. Increase memory limits:**
```yaml
# values.yaml
prometheus:
  resources:
    limits:
      memory: "2Gi"
```

**B. Reduce retention time:**
Update Deployment args:
```yaml
- '--storage.tsdb.retention.time=7d'  # Reduced from 15d
```

**C. Reduce scrape frequency:**
```yaml
# values.yaml
prometheus:
  scrapeInterval: 30s  # Increased from 15s
```

**D. Reduce metric cardinality:**
If FastAPI is exposing too many metrics with too many label combinations.

### Issue 6: "Cannot open /metrics endpoint"

**Symptoms:**
Direct curl to `/metrics` returns error:
```bash
curl http://localhost:8000/metrics
# 404 Not Found
```

**Diagnosis:**
```bash
# Check if FastAPI has /metrics endpoint
kubectl logs wiki-chart-fastapi-xxx | grep metrics
```

**Fix:**
The `/metrics` endpoint should already exist in `main.py`. If not, ensure you have:
```python
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST

@app.get("/metrics")
async def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)
```

---

## Best Practices and Production Considerations

### 1. Configuration Management

**Development:**
```yaml
prometheus:
  scrapeInterval: 15s
  persistence:
    size: 2Gi
  resources:
    limits:
      memory: 1Gi
```

**Production:**
```yaml
prometheus:
  scrapeInterval: 30s  # Reduce load
  persistence:
    size: 50Gi  # More storage
    storageClass: fast-ssd  # Better performance
  resources:
    limits:
      memory: 4Gi  # More memory for complex queries
      cpu: 2000m
```

### 2. Backup Strategy

Prometheus data is valuable for incident investigation. Consider:

**A. PVC Snapshots (if supported by storage provider):**
```bash
# Create snapshot
kubectl create volumesnapshot prometheus-snapshot \
  --source-pvc=wiki-chart-prometheus-pvc

# Restore from snapshot
kubectl create pvc --from-snapshot=prometheus-snapshot
```

**B. Remote Storage:**
For long-term retention, use remote storage:
- **Thanos**: Object storage backend (S3, GCS, Azure)
- **Cortex**: Multi-tenant Prometheus
- **M3DB**: Distributed time-series database
- **Victoria Metrics**: Long-term storage

### 3. Security Hardening

**A. Authentication:**
Prometheus has no built-in authentication. Options:
- Use Ingress with OAuth2 proxy
- Use reverse proxy with basic auth
- Limit access to cluster-internal only (ClusterIP)

**B. Network Policies:**
Restrict which pods can scrape which services:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prometheus-network-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: monitoring
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/component: visualization  # Grafana only
```

**C. RBAC:**
If using Kubernetes service discovery (not in our setup), configure RBAC:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources: ["nodes", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
```

### 4. Scalability

For high-scale deployments:

**A. Prometheus Federation:**
```
Prometheus (central)
    ↓ Federate
    ├── Prometheus (region-1)
    ├── Prometheus (region-2)
    └── Prometheus (region-3)
```

**B. Thanos:**
```
Prometheus → Thanos Sidecar → Object Storage (S3)
                ↓
          Thanos Query (multi-region queries)
                ↓
          Grafana
```

**C. Horizontal Sharding:**
Split scrape targets across multiple Prometheus instances:
```yaml
# Prometheus 1: Scrape targets with label "shard=1"
# Prometheus 2: Scrape targets with label "shard=2"
```

---

## What We've Accomplished

In Phase 7, we've successfully:

✅ **Deployed Prometheus** to Kubernetes
✅ **Configured metric scraping** from FastAPI `/metrics` endpoint
✅ **Enabled persistent storage** for 15 days of metrics
✅ **Set up self-monitoring** (Prometheus monitoring itself)
✅ **Added health endpoint** to FastAPI application
✅ **Configured health probes** for Prometheus pod
✅ **Set resource limits** to prevent resource exhaustion

**Observability Foundation:**
- Metrics are now being collected every 15 seconds
- Historical data available for trend analysis
- Foundation for Grafana dashboards (Phase 8)
- Ability to query metrics via PromQL

**What We Can Now Do:**
1. **Monitor application behavior**: See user and post creation trends
2. **Debug performance issues**: Query response times and error rates
3. **Capacity planning**: Analyze resource usage over time
4. **Alerting foundation**: Metrics available for alert rules (future)

---

## Next Steps: Phase 8 - Grafana Visualization

Phase 8 will build on our monitoring foundation by adding **Grafana** for beautiful, interactive dashboards.

### What We'll Add in Phase 8

**1. Grafana Deployment:**
- Grafana server deployment
- Persistent storage for dashboards
- Resource management

**2. Datasource Configuration:**
- Auto-configure Prometheus as datasource
- Pre-provisioned connection to `http://wiki-chart-prometheus:9090`

**3. Dashboard Provisioning:**
- **FastAPI Performance Dashboard**:
  - Request rate (requests per second)
  - User creation rate
  - Post creation rate
  - Response time percentiles (p50, p95, p99)
  
- **Resource Usage Dashboard**:
  - CPU usage
  - Memory usage
  - Python garbage collection stats
  
- **Prometheus Health Dashboard**:
  - TSDB metrics
  - Scrape performance
  - Storage usage

**4. Grafana Service:**
- ClusterIP service for internal access
- Preparation for Ingress (Phase 9)

### Preview: Grafana Datasource Config

```yaml
# Grafana will be configured to use Prometheus
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://wiki-chart-prometheus:9090
      isDefault: true
```

### Preview: Example Dashboard Panel

A Grafana panel showing user creation rate:
```json
{
  "title": "User Creation Rate",
  "targets": [
    {
      "expr": "rate(users_created_total[5m])",
      "legendFormat": "Users per second"
    }
  ],
  "visualization": "graph"
}
```

### Benefits of Grafana

| Current (Phase 7) | With Grafana (Phase 8) |
|-------------------|------------------------|
| Query metrics manually | Pre-built interactive dashboards |
| Text-based results | Beautiful graphs and charts |
| One metric at a time | Multiple metrics in one view |
| No historical comparison | Compare time ranges easily |
| Basic Prometheus UI | Professional monitoring UI |
| No sharing | Share dashboards with team |

---

## Summary

Phase 7 represents a critical milestone in building a **production-ready observability stack**. We've transformed our application from "black box" to transparent, measurable system.

**Key Learnings:**

1. **Monitoring Architecture**: Pull-based scraping, time-series storage, and PromQL queries
2. **Persistent Storage**: Why and how to use PVCs for stateful applications
3. **Health Probes**: Liveness vs readiness, and self-healing patterns
4. **Resource Management**: Setting appropriate limits for monitoring systems
5. **Configuration Management**: Using ConfigMaps for application configuration

**The Observability Journey:**

```
Phase 1-6: Built the application and infrastructure
    ↓
Phase 7: Added monitoring (you are here! 🎯)
    ↓
Phase 8: Add visualization (Grafana dashboards)
    ↓
Phase 9: Add external access (Ingress)
    ↓
Phase 10+: Add alerting, SLOs, and advanced features
```

You now have a solid foundation for understanding how production systems are monitored. These concepts apply to any distributed system, from small startups to large-scale platforms like Netflix, Uber, and Google.

**Welcome to the world of observability!** 🚀📊

---

## Additional Resources

### Official Documentation
- **Prometheus**: https://prometheus.io/docs/
- **PromQL**: https://prometheus.io/docs/prometheus/latest/querying/basics/
- **Prometheus Client Python**: https://github.com/prometheus/client_python

### Best Practices
- **Metric Naming**: https://prometheus.io/docs/practices/naming/
- **Instrumentation**: https://prometheus.io/docs/practices/instrumentation/
- **Recording Rules**: https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/

### Learning Resources
- **PromQL Tutorial**: https://prometheus.io/docs/prometheus/latest/querying/examples/
- **Prometheus Best Practices**: https://prometheus.io/docs/practices/
- **Monitoring Best Practices**: https://sre.google/sre-book/monitoring-distributed-systems/

### Community
- **Prometheus GitHub**: https://github.com/prometheus/prometheus
- **CNCF Slack**: #prometheus channel
- **Prometheus Users Mailing List**: https://groups.google.com/forum/#!forum/prometheus-users

---

*Phase 7 Complete! Ready for Phase 8: Grafana Visualization* 🎉
