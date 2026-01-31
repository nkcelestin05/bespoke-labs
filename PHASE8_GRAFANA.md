# Phase 8: Grafana Visualization Deployment

## Overview

In Phase 8, we deploy Grafana to visualize the metrics collected by Prometheus. This phase completes our observability stack by providing interactive dashboards and beautiful visualizations of our FastAPI application's performance and health.

**What we're deploying:**
- Grafana visualization server (web UI for dashboards)
- Persistent storage for dashboards and configuration
- Auto-configured Prometheus datasource
- Admin credentials for initial access

**Why visualization matters:**
- Metrics alone are just numbers - visualization reveals patterns
- Dashboards make data accessible to non-technical stakeholders
- Real-time monitoring of application health at a glance
- Historical analysis to understand trends and anomalies
- Enables data-driven decision making
- Faster incident detection and resolution

**The Observability Journey:**
- **Phase 6**: FastAPI exposes metrics at `/metrics` endpoint
- **Phase 7**: Prometheus scrapes and stores metrics over time
- **Phase 8**: Grafana visualizes metrics in interactive dashboards ← We are here
- **Phase 9**: Ingress exposes Grafana externally for team access

---

## Files Created

### 1. `grafana-configmap-datasources.yaml`
Automatically configures Prometheus as a datasource in Grafana on startup.

### 2. `grafana-pvc.yaml`
Requests persistent storage (1Gi) to save dashboards and configuration.

### 3. `grafana-deployment.yaml`
Manages the Grafana server pod with proper configuration and security.

### 4. `grafana-service.yaml`
Provides stable internal networking for accessing Grafana UI.

---

## What is Grafana?

### The Visualization Problem

Imagine you're a restaurant manager. Your kitchen has sensors tracking:
- Orders per hour: `[42, 38, 51, 67, 89, 103, 95, 72, 58, 44]`
- Average preparation time: `[8.2, 7.9, 9.1, 12.3, 15.7, 14.2, 10.8, 9.3, 8.7, 7.5]`
- Failed orders: `[2, 1, 3, 5, 8, 7, 4, 2, 1, 0]`

Looking at raw numbers, can you quickly answer:
- Is the kitchen getting overwhelmed during rush hours?
- What's the trend - getting better or worse?
- When did the problem start?

**Without visualization**: Staring at numbers, hard to spot patterns.

**With Grafana**: 
```
Orders per Hour
┌─────────────────────────────────┐
│       ╱╲                        │
│      ╱  ╲                       │
│     ╱    ╲___                   │
│   ╱╲          ╲___              │
│  ╱  ╲              ╲___         │
│ ╱                      ╲___     │
└─────────────────────────────────┘
12pm  1pm  2pm  3pm  4pm  5pm

✅ Instantly see: Lunch rush (12-1pm), dinner rush (5-6pm)
✅ Spot problem: Prep time increases during rush
✅ Identify solution: Need more kitchen staff 5-6pm
```

### Grafana Solution

**Grafana** is an open-source visualization and analytics platform that:
1. **Connects to datasources** (Prometheus, databases, etc.)
2. **Queries data** using datasource query languages (PromQL for Prometheus)
3. **Renders visualizations** (graphs, charts, tables, heatmaps)
4. **Organizes dashboards** to tell a story with your data
5. **Enables alerting** when metrics cross thresholds
6. **Supports collaboration** with teams via shared dashboards

### Key Concepts

#### 1. Datasources

A **datasource** is where Grafana gets data from.

**Our datasource configuration:**
```yaml
datasources:
  - name: Prometheus
    type: prometheus
    url: http://wiki-chart-prometheus:9090
    isDefault: true
```

**Common datasource types:**
- **Prometheus**: Time-series metrics (our use case)
- **PostgreSQL/MySQL**: Database queries
- **Elasticsearch**: Log aggregation and search
- **InfluxDB**: Time-series data
- **Graphite**: Metrics storage
- **CloudWatch/Azure Monitor**: Cloud provider metrics

**Access modes:**
- **Proxy**: Grafana server queries datasource (hides credentials, avoids CORS)
- **Direct**: Browser queries datasource directly (faster, but exposes datasource)

**Why we use proxy:**
- Security: Prometheus not exposed to browsers
- Network: Browser doesn't need cluster access
- CORS: No cross-origin issues

#### 2. Dashboards

A **dashboard** is a collection of panels showing visualizations.

**Dashboard structure:**
```
┌─────────────────────────────────────────────────┐
│  FastAPI Application Monitoring                 │  ← Dashboard Title
├─────────────┬─────────────┬─────────────────────┤
│ Users       │ Posts       │ Request Rate        │  ← Row 1: Key Metrics
│ Total: 142  │ Total: 67   │ 12.3 req/s          │
├─────────────┴─────────────┴─────────────────────┤
│ User Creation Rate (last 6 hours)               │  ← Row 2: Graph Panel
│ ┌───────────────────────────────────────────┐   │
│ │   ╱╲         ╱╲                          │   │
│ │  ╱  ╲       ╱  ╲       ╱╲                │   │
│ │ ╱    ╲_____╱    ╲_____╱  ╲___            │   │
│ └───────────────────────────────────────────┘   │
├─────────────────────────────────────────────────┤
│ Response Time Distribution                      │  ← Row 3: Heatmap
│ [heatmap visualization]                         │
└─────────────────────────────────────────────────┘
```

**Dashboard components:**
- **Panels**: Individual visualizations (graph, stat, table, etc.)
- **Rows**: Organize panels into collapsible sections
- **Variables**: Dynamic filters (e.g., select time range, pod name)
- **Annotations**: Mark events on graphs (deployments, incidents)

#### 3. Panels and Visualizations

**Panel types:**

| Type | Use Case | Example |
|------|----------|---------|
| **Time Series** | Show trends over time | Request rate, CPU usage |
| **Stat** | Single value with threshold colors | Current user count |
| **Gauge** | Progress toward limit | Memory usage (0-100%) |
| **Bar Chart** | Compare categories | Requests by endpoint |
| **Table** | Detailed data view | Error logs |
| **Heatmap** | Distribution over time | Response time percentiles |
| **Pie Chart** | Proportions | Error types breakdown |

**Our application metrics work best with:**
- **Time Series**: `users_created_total` and `posts_created_total` over time
- **Stat**: Current total counts
- **Table**: Recent user/post creation events

#### 4. Queries and Transformations

**Query language**: PromQL (Prometheus Query Language)

**Example queries for our application:**

```promql
# 1. Total users created
users_created_total

# 2. Rate of user creation (users per second, 5-minute average)
rate(users_created_total[5m])

# 3. Rate per minute (more readable)
rate(users_created_total[5m]) * 60

# 4. Total posts created
posts_created_total

# 5. Ratio of posts to users (engagement metric)
posts_created_total / users_created_total

# 6. Prometheus self-monitoring: scrape duration
prometheus_target_scrape_duration_seconds{job=\"fastapi\"}
```

**Transformations**: Modify query results before visualization
- **Calculate**: Add computed fields (e.g., percentage)
- **Filter**: Show only specific series
- **Merge**: Combine multiple queries
- **Rename**: Change series names for clarity

#### 5. Auto-Provisioning

**Manual setup** (traditional way):
1. Deploy Grafana
2. Log in to UI
3. Click "Add datasource"
4. Enter Prometheus URL
5. Click "Save & Test"

**Auto-provisioning** (our approach):
```yaml
# ConfigMap: grafana-configmap-datasources.yaml
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus-service:9090
    isDefault: true
```

**Benefits:**
- **Infrastructure as Code**: Datasource config in Git
- **Reproducible**: Same setup across environments
- **Automated**: No manual UI clicks needed
- **Consistent**: Dev/staging/prod have identical config

**What gets auto-provisioned:**
- ✅ Datasources (Prometheus)
- ✅ Dashboards (can be added to ConfigMap)
- ⚠️ Users (still need manual creation or external auth)
- ⚠️ Plugins (require installation step)

---

## Detailed Component Explanation

### Part 1: Datasource ConfigMap - Connecting to Prometheus

#### What This ConfigMap Does

The datasource ConfigMap automatically configures Prometheus as a datasource when Grafana starts.

**Configuration flow:**
```
1. Kubernetes creates ConfigMap
2. ConfigMap mounted to /etc/grafana/provisioning/datasources/
3. Grafana starts and reads provisioning directory
4. Grafana automatically adds Prometheus datasource
5. Datasource ready to use immediately (no UI clicks needed)
```

#### Configuration Breakdown

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://wiki-chart-prometheus:9090
    isDefault: true
```

**Field explanations:**

**`name: Prometheus`**
- Display name in Grafana UI
- Users see this when selecting datasource
- Can be anything, but "Prometheus" is clear

**`type: prometheus`**
- Tells Grafana which plugin to use
- Grafana includes Prometheus plugin by default
- Other types: `mysql`, `postgres`, `elasticsearch`, etc.

**`access: proxy`**
- Grafana server makes requests to Prometheus
- Alternative: `direct` (browser makes requests)

**Why proxy is better:**
```
Direct Access:
  Browser → Prometheus
  ❌ Browser needs network access to Prometheus
  ❌ CORS issues
  ❌ Exposes Prometheus to clients

Proxy Access:
  Browser → Grafana → Prometheus
  ✅ Browser only needs Grafana access
  ✅ No CORS issues
  ✅ Prometheus stays internal
  ✅ Credentials hidden from browser
```

**`url: http://wiki-chart-prometheus:9090`**
- Kubernetes service DNS name
- Full form: `http://wiki-chart-prometheus.default.svc.cluster.local:9090`
- Short form works within same namespace

**How DNS resolution works:**
```
1. Grafana queries: wiki-chart-prometheus:9090
2. Kubernetes DNS resolves to: 10.96.0.42 (ClusterIP)
3. Request routed to Prometheus pod
4. Prometheus returns metrics data
```

**`isDefault: true`**
- This datasource is pre-selected in new panels
- Only one datasource should be default
- Users can manually select other datasources

#### Additional Configuration Options

```yaml
jsonData:
  timeInterval: "15s"
  httpMethod: POST
  queryTimeout: 60
```

**`timeInterval: \"15s\"`**
- Minimum step for Prometheus queries
- Should match Prometheus scrape interval (15s)
- Ensures query granularity matches data granularity

**Example impact:**
```
With timeInterval: 15s
  Query: rate(users_created_total[5m])
  Data points: Every 15 seconds
  Result: Smooth graph

With timeInterval: 1s
  Query: rate(users_created_total[5m])
  Data points: Every 1 second (but data only collected every 15s)
  Result: Gaps in graph, misleading
```

**`httpMethod: POST`**
- Use POST for Prometheus queries
- Alternative: GET (limited by URL length)
- POST is recommended for complex queries

**`queryTimeout: 60`**
- Maximum query execution time (seconds)
- Prevents slow queries from hanging forever
- Adjust if queries consistently timeout

---

### Part 2: PersistentVolumeClaim - Storing Dashboards

#### What Grafana Stores

Grafana uses an embedded **SQLite database** to store:

**1. Dashboards**
```sql
-- dashboards table
id    title                          data (JSON)
1     FastAPI Monitoring            {...}
2     PostgreSQL Performance        {...}
3     Kubernetes Cluster Overview   {...}
```

**2. Users and Permissions**
```sql
-- users table
id    username    email                 role
1     admin       admin@example.com     Admin
2     viewer      viewer@example.com    Viewer
```

**3. Datasources** (if not provisioned)
- Manually added datasources
- Credentials and settings

**4. Preferences**
- UI theme (dark/light)
- Home dashboard
- Timezone settings

**5. Annotations**
- Manual events marked on graphs
- Deployment markers
- Incident notes

**6. API Keys and Sessions**
- Authentication tokens
- Active user sessions

#### Why Persistence Matters

**Without PVC:**
```
Day 1: Create beautiful dashboards (2 hours of work)
Day 2: Pod restarts due to upgrade
Day 3: All dashboards gone! 😱
Result: Frustrated team, wasted time
```

**With PVC:**
```
Day 1: Create beautiful dashboards (2 hours of work)
Day 2: Pod restarts due to upgrade
Day 3: All dashboards still there! 😊
Result: Happy team, professional setup
```

#### Storage Requirements

**Calculation:**
```
Grafana binary + dependencies:  ~100 MB
SQLite database (typical):       ~10 MB
Installed plugins:              ~50-200 MB
Logs and temp files:             ~50 MB
────────────────────────────────────────
Typical usage:                  ~300 MB
Buffer for growth:              ~700 MB
────────────────────────────────────────
Total allocation:                 1 Gi
```

**Database size factors:**
- Number of dashboards: ~10-50 KB each
- Number of users: ~1-5 KB each
- Query history: Can grow over time
- Annotations: Depends on usage

**When to increase storage:**
- Installing many plugins (>10)
- Hundreds of dashboards
- Large user base (>100 users)
- Extensive query history

#### SQLite vs External Database

**SQLite (our choice):**
- ✅ Simple: No external database needed
- ✅ Fast: Direct file access
- ✅ Lightweight: Embedded in Grafana
- ❌ Single instance: Can't have multiple Grafana replicas
- ❌ No HA: Single point of failure

**External PostgreSQL/MySQL:**
- ✅ High availability: Multiple Grafana replicas
- ✅ Better performance: Optimized for concurrent access
- ✅ Backup friendly: Standard DB backup tools
- ❌ More complex: Requires database setup
- ❌ Higher cost: Additional resource usage

**When to switch to external DB:**
- Scaling to multiple Grafana replicas
- Enterprise deployment with HA requirements
- Large number of concurrent users (>50)
- Compliance requiring database backups

---

### Part 3: Deployment - Running Grafana

#### Security Context

```yaml
securityContext:
  fsGroup: 472
  runAsUser: 472
  runAsNonRoot: true
```

**Why run as non-root?**
- **Security**: Limits damage if container is compromised
- **Best practice**: Principle of least privilege
- **Compliance**: Many security policies require non-root

**UID 472**: Official Grafana user
- Pre-configured in Grafana Docker image
- Has permission to write to `/var/lib/grafana`
- Standard across all Grafana deployments

**What happens if you remove securityContext:**
```
❌ Container runs as root (UID 0)
❌ Security vulnerability if compromised
❌ May fail if cluster has Pod Security Standards
```

#### Environment Variables

Grafana configuration comes from multiple sources:
1. **grafana.ini** (default config file)
2. **Environment variables** (override grafana.ini)
3. **Config files** in `/etc/grafana/`

We use environment variables for:
- Easy templating with values.yaml
- No need to manage grafana.ini
- Clear, explicit configuration

**Critical environment variables:**

**Admin Credentials:**
```yaml
- name: GF_SECURITY_ADMIN_USER
  value: admin
- name: GF_SECURITY_ADMIN_PASSWORD
  value: admin
```

**⚠️ SECURITY WARNING:**
```
Current setup: Credentials in values.yaml (PLAIN TEXT)
Production risk: Anyone with repo access sees passwords

Better approach: Kubernetes Secret
```

**How to use Secret (recommended for production):**
```yaml
# 1. Create Secret
apiVersion: v1
kind: Secret
metadata:
  name: grafana-secret
type: Opaque
data:
  admin-password: <base64-encoded-password>

# 2. Reference in Deployment
- name: GF_SECURITY_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: grafana-secret
      key: admin-password
```

**Database Configuration:**
```yaml
- name: GF_DATABASE_TYPE
  value: sqlite3
- name: GF_DATABASE_PATH
  value: /var/lib/grafana/grafana.db
```

**Why SQLite:**
- Simple: No external database needed
- Sufficient: For single-instance deployments
- Fast: Direct file access on local disk

**Alternative: PostgreSQL**
```yaml
- name: GF_DATABASE_TYPE
  value: postgres
- name: GF_DATABASE_HOST
  value: postgres-service:5432
- name: GF_DATABASE_NAME
  value: grafana
- name: GF_DATABASE_USER
  value: grafana
- name: GF_DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: grafana-db-secret
      key: password
```

**Logging Configuration:**
```yaml
- name: GF_LOG_MODE
  value: console
- name: GF_LOG_LEVEL
  value: info
```

**Log modes:**
- `console`: Stdout (best for Kubernetes - captured by `kubectl logs`)
- `file`: Write to `/var/log/grafana/` (requires log volume)
- `syslog`: Send to syslog server

**Log levels:**
- `trace`: Everything (very verbose, debugging)
- `debug`: Detailed (troubleshooting)
- `info`: Standard (normal operation) ← Our choice
- `warn`: Warnings only
- `error`: Errors only

**Analytics Configuration:**
```yaml
- name: GF_ANALYTICS_REPORTING_ENABLED
  value: \"false\"
- name: GF_ANALYTICS_CHECK_FOR_UPDATES
  value: \"false\"
```

**Why disable:**
- **Privacy**: No usage data sent to Grafana Labs
- **Air-gapped**: Works without internet
- **Security**: No external connections

**What's reported (if enabled):**
- Grafana version
- OS and architecture
- Number of dashboards and users
- Anonymous usage statistics

#### Health Probes

**Liveness Probe** (Is Grafana alive?):
```yaml
livenessProbe:
  httpGet:
    path: /api/health
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
```

**What `/api/health` checks:**
```json
{
  \"database\": \"ok\",
  \"version\": \"10.2.3\"
}
```

**Failure scenarios:**
- Database connection lost
- Process deadlocked
- Out of memory (before OOMKill)

**What happens on failure:**
1. First failure: Logged, no action
2. Second failure: Logged, warning
3. Third failure: Pod killed and restarted

**Readiness Probe** (Is Grafana ready?):
```yaml
readinessProbe:
  httpGet:
    path: /api/health
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3
```

**When readiness fails:**
- Startup: Database migrations in progress
- Operation: High load, slow queries
- Result: Pod removed from Service endpoints (no traffic)

**Liveness vs Readiness:**

| Phase | Liveness | Readiness | Traffic | Action |
|-------|----------|-----------|---------|--------|
| Starting | ✅ | ❌ | None | Wait for ready |
| Running | ✅ | ✅ | Yes | Normal operation |
| Overloaded | ✅ | ❌ | None | Recover without restart |
| Crashed | ❌ | ❌ | None | Restart container |

#### Volume Mounts

**Mount 1: Persistent Storage**
```yaml
- name: storage
  mountPath: /var/lib/grafana
```

**What's in `/var/lib/grafana`:**
```
/var/lib/grafana/
├── grafana.db          # SQLite database (dashboards, users)
├── grafana.db-shm      # Shared memory file (SQLite)
├── grafana.db-wal      # Write-ahead log (SQLite)
├── plugins/            # Installed plugins
│   ├── custom-panel/
│   └── datasource-xyz/
├── png/                # Generated dashboard images
│   └── dashboard-1.png
└── sessions/           # User session files
    └── session-abc123
```

**Mount 2: Datasource Configuration**
```yaml
- name: datasources
  mountPath: /etc/grafana/provisioning/datasources
  readOnly: true
```

**What's in `/etc/grafana/provisioning/datasources`:**
```
/etc/grafana/provisioning/datasources/
└── datasources.yaml    # Auto-provisioned Prometheus config
```

**Provisioning flow:**
```
1. Grafana starts
2. Reads /etc/grafana/provisioning/ directory
3. Loads datasources/*.yaml files
4. Adds Prometheus datasource automatically
5. Datasource available immediately (no UI needed)
```

---

### Part 4: Service - Accessing Grafana

#### Service Type: ClusterIP

**ClusterIP characteristics:**
```
✅ Internal cluster IP (e.g., 10.96.0.50)
✅ DNS name: wiki-chart-grafana.default.svc.cluster.local
✅ Accessible from any pod in cluster
❌ NOT accessible from outside cluster
```

**Access methods:**

**1. Port-forward (Development):**
```bash
kubectl port-forward svc/wiki-chart-grafana 3000:3000

# Then open: http://localhost:3000
```

**2. Ingress (Production - Phase 9):**
```
Internet → Ingress → Service → Pod
https://example.com/grafana → ClusterIP:3000 → 10.244.0.5:3000
```

**3. From another pod:**
```bash
# Execute in FastAPI pod
kubectl exec -it fastapi-pod -- curl http://wiki-chart-grafana:3000/api/health
```

#### Session Affinity

```yaml
sessionAffinity: ClientIP
sessionAffinityConfig:
  clientIP:
    timeoutSeconds: 10800
```

**Why session affinity for Grafana?**

**Without affinity:**
```
Request 1: User logs in → Pod A → Session created
Request 2: User views dashboard → Pod B → Session not found! ❌
Result: User kicked out, must log in again
```

**With affinity:**
```
Request 1: User logs in → Pod A → Session created
Request 2: User views dashboard → Pod A (same pod) → Session found! ✅
Request 3: User creates dashboard → Pod A (same pod) → Works! ✅
Result: Smooth user experience
```

**How it works:**
1. User makes first request
2. Service notes client IP (e.g., 192.168.1.100)
3. Routes to Pod A
4. Stores mapping: 192.168.1.100 → Pod A
5. All future requests from 192.168.1.100 go to Pod A
6. After 10800 seconds (3 hours), mapping expires

**When affinity doesn't work:**
- User behind NAT: Multiple users appear as same IP
- Mobile users: IP changes when switching networks
- Long sessions: Timeout expires

**Better solutions for HA:**
- Store sessions in Redis (external session storage)
- Use external database for Grafana (PostgreSQL)
- Enable session persistence across pods

---

## Testing the Deployment

### Step 1: Validate Helm Templates

```bash
# Navigate to project root
cd /path/to/bespoke-labs

# Check for syntax errors
helm lint ./wiki-chart

# Expected output:
# ==> Linting ./wiki-chart
# [INFO] Chart.yaml: icon is recommended
# 
# 1 chart(s) linted, 0 chart(s) failed
```

**What `helm lint` validates:**
- YAML syntax errors
- Required Chart.yaml fields
- Template rendering issues
- Values.yaml structure
- Best practices compliance

### Step 2: Render Templates (Dry Run)

```bash
# Render all templates to see final YAML
helm template wiki-chart ./wiki-chart > /tmp/rendered-grafana.yaml

# View Grafana resources
grep -A 30 \"kind: ConfigMap\" /tmp/rendered-grafana.yaml | grep -A 30 \"grafana-datasources\"
grep -A 20 \"kind: PersistentVolumeClaim\" /tmp/rendered-grafana.yaml | grep -A 20 \"grafana-pvc\"
grep -A 150 \"kind: Deployment\" /tmp/rendered-grafana.yaml | grep -A 150 \"grafana\"
grep -A 30 \"kind: Service\" /tmp/rendered-grafana.yaml | grep -A 30 \"grafana\"
```

**What to verify:**
- ✅ ConfigMap contains Prometheus datasource URL
- ✅ PVC requests 1Gi storage
- ✅ Deployment has correct image tag (grafana/grafana:10.2.3)
- ✅ Deployment mounts both volumes (storage + datasources)
- ✅ Service selector matches deployment labels
- ✅ Environment variables set correctly (admin user/password)

### Step 3: Deploy to Kubernetes

```bash
# Install or upgrade the Helm chart
helm upgrade --install wiki-chart ./wiki-chart

# Expected output:
# Release \"wiki-chart\" has been upgraded. Happy Helming!
# NAME: wiki-chart
# LAST DEPLOYED: [timestamp]
# NAMESPACE: default
# STATUS: deployed
# REVISION: 3
```

**What happens during deployment:**
1. Helm renders templates with values.yaml
2. Creates ConfigMap (datasource configuration)
3. Creates PVC (storage provisioned)
4. Creates Deployment (pod scheduled)
5. Creates Service (ClusterIP assigned)

**Deployment order:**
- ConfigMap and PVC created first
- Deployment waits for PVC to be Bound
- Pod starts once PVC is available
- Service routes traffic to pod once ready

### Step 4: Verify Grafana Pod is Running

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/component=visualization

# Expected output:
# NAME                               READY   STATUS    RESTARTS   AGE
# wiki-chart-grafana-5d7f9c8b6-xyz   1/1     Running   0          2m
```

**Pod states:**
| State | Meaning | Action |
|-------|---------|--------|
| `Pending` | Waiting for PVC or node | Wait or check PVC status |
| `ContainerCreating` | Pulling image, mounting volumes | Wait (can take 1-2 min) |
| `Running` | Grafana is up! | Proceed to next step |
| `CrashLoopBackOff` | Startup failing | Check logs |
| `Error` | Container exited | Check logs |

**If not running:**
```bash
# Check pod events
kubectl describe pod -l app.kubernetes.io/component=visualization

# Check pod logs
kubectl logs -l app.kubernetes.io/component=visualization

# Common issues:
# - PVC not bound: Check storage class
# - Image pull error: Check image tag
# - Permission denied: Check securityContext
# - Database error: Check volume mount
```

### Step 5: Verify PVC is Bound

```bash
# Check PVC status
kubectl get pvc

# Expected output:
# NAME                      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# wiki-chart-grafana-pvc    Bound    pvc-xyz-abc-123                           1Gi        RWO            standard       2m
```

**PVC states:**
- `Pending`: Waiting for storage provisioner (check storage class)
- `Bound`: Volume created and attached! ✅

**If stuck in Pending:**
```bash
# Check storage classes
kubectl get storageclass

# Check PVC events
kubectl describe pvc wiki-chart-grafana-pvc

# Common issues:
# - No default storage class: Set one or specify in values.yaml
# - Storage class doesn't exist: Use available class
# - Insufficient storage: Free up space or reduce request
```

### Step 6: Check Grafana Logs

```bash
# View Grafana startup logs
kubectl logs -l app.kubernetes.io/component=visualization --tail=50

# Expected output should include:
# logger=settings t=... lvl=info msg=\"Config loaded from\" file=/usr/share/grafana/conf/defaults.ini
# logger=sqlstore t=... lvl=info msg=\"Connecting to DB\" dbtype=sqlite3
# logger=migrator t=... lvl=info msg=\"Starting DB migrations\"
# logger=migrator t=... lvl=info msg=\"migrations completed\"
# logger=plugin.manager t=... lvl=info msg=\"Plugin registered\" pluginId=prometheus
# logger=provisioning.datasources t=... lvl=info msg=\"inserted datasource\" name=Prometheus
# logger=http.server t=... lvl=info msg=\"HTTP Server Listen\" address=[::]:3000
```

**Key log messages:**

**✅ Success indicators:**
```
\"Config loaded from\"        → Configuration loaded
\"Connecting to DB\"          → Database connection started
\"migrations completed\"      → Database schema up to date
\"Plugin registered\"         → Prometheus plugin available
\"inserted datasource\"       → Auto-provisioning worked!
\"HTTP Server Listen\"        → Grafana ready for connections
```

**❌ Error indicators:**
```
\"Failed to start plugin\"    → Plugin issue
\"Database migration failed\" → Database error
\"Failed to provision\"       → ConfigMap mount issue
\"Permission denied\"         → Volume permission issue
```

### Step 7: Access Grafana UI

```bash
# Port-forward to access Grafana UI locally
kubectl port-forward svc/wiki-chart-grafana 3000:3000

# Output:
# Forwarding from 127.0.0.1:3000 -> 3000
# Forwarding from [::1]:3000 -> 3000
```

**Open in browser:** http://localhost:3000

**Login credentials:**
- **Username:** `admin` (from values.yaml: `grafana.adminUser`)
- **Password:** `admin` (from values.yaml: `grafana.adminPassword`)

**What you should see:**
1. Grafana login page
2. Enter credentials
3. Welcome page or dashboard list

**If you see:**
- ❌ Connection refused: Pod not running or service not ready
- ❌ 502 Bad Gateway: Pod exists but not responding (check health)
- ✅ Login page: Success! Proceed to next step

**Note:** Port-forward runs in foreground. Press `Ctrl+C` to stop.

### Step 8: Verify Prometheus Datasource

**In Grafana UI:**
1. Click **☰** (menu) → **Connections** → **Data sources**
2. You should see: **Prometheus** (default)

**Verify datasource is working:**
1. Click **Prometheus** datasource
2. Scroll down to bottom
3. Click **Save & Test** button
4. Expected result: ✅ **\"Data source is working\"**

**What this tests:**
- Grafana can reach Prometheus URL
- Prometheus API is responding
- Network connectivity is working
- Datasource configuration is correct

**If test fails:**

**❌ \"HTTP Error 502\"**
```
Cause: Cannot reach Prometheus
Fix: Check Prometheus is running:
     kubectl get pods -l app.kubernetes.io/component=monitoring
```

**❌ \"HTTP Error 400: Bad Request\"**
```
Cause: Invalid Prometheus URL
Fix: Check datasource URL in ConfigMap
     Should be: http://wiki-chart-prometheus:9090
```

**❌ \"Timeout\"**
```
Cause: Prometheus not responding
Fix: Check Prometheus logs:
     kubectl logs -l app.kubernetes.io/component=monitoring
```

### Step 9: Create Your First Dashboard

Let's create a simple dashboard to visualize our metrics!

#### Step 9.1: Create Dashboard

1. Click **☰** → **Dashboards** → **New** → **New Dashboard**
2. Click **Add visualization**
3. Select **Prometheus** datasource
4. You're now in the panel editor!

#### Step 9.2: Add Users Created Panel

**Panel 1: Total Users Created (Stat)**

1. In the **Query** section:
   - Metric: Enter `users_created_total`
   - Click **Run queries**
   - You should see a number!

2. In the **Panel options** (right sidebar):
   - Title: `Total Users Created`
   - Description: `Total number of users created since application start`

3. In the **Visualization** dropdown (top):
   - Select **Stat**

4. In the **Stat styles**:
   - Graph mode: None
   - Color mode: Value
   - Text size: Auto

5. Click **Apply** (top right)

You now have your first panel showing total users!

#### Step 9.3: Add User Creation Rate Panel

**Panel 2: User Creation Rate (Time Series)**

1. Click **Add** → **Visualization**
2. Select **Prometheus** datasource
3. In the **Query** section:
   ```promql
   rate(users_created_total[5m]) * 60
   ```
   - This shows users created per minute (5-minute average)

4. Panel options:
   - Title: `User Creation Rate`
   - Description: `Users created per minute (5-minute moving average)`

5. Visualization: **Time series** (default)

6. In **Graph styles**:
   - Style: Line
   - Line width: 2
   - Fill opacity: 10

7. Click **Apply**

#### Step 9.4: Add Posts Created Panel

**Panel 3: Total Posts Created (Stat)**

1. Click **Add** → **Visualization**
2. Query: `posts_created_total`
3. Title: `Total Posts Created`
4. Visualization: **Stat**
5. Click **Apply**

#### Step 9.5: Add Posts Creation Rate Panel

**Panel 4: Post Creation Rate (Time Series)**

1. Click **Add** → **Visualization**
2. Query:
   ```promql
   rate(posts_created_total[5m]) * 60
   ```
3. Title: `Post Creation Rate (per minute)`
4. Visualization: **Time series**
5. Click **Apply**

#### Step 9.6: Add Engagement Metric

**Panel 5: Posts per User Ratio (Stat)**

1. Click **Add** → **Visualization**
2. Query:
   ```promql
   posts_created_total / users_created_total
   ```
3. Title: `Posts per User`
4. Description: `Average number of posts per user`
5. Visualization: **Stat**
6. In **Standard options**:
   - Unit: `none`
   - Decimals: 2
7. Click **Apply**

#### Step 9.7: Save Dashboard

1. Click **💾 Save** (top right)
2. Dashboard name: `FastAPI Application Monitoring`
3. Description: `Overview of user and post creation metrics`
4. Folder: General
5. Click **Save**

**🎉 Congratulations!** You've created your first Grafana dashboard!

### Step 10: Generate Test Traffic

Let's generate some activity to see the dashboard in action!

```bash
# Open a new terminal and port-forward FastAPI
kubectl port-forward svc/wiki-chart-fastapi 8000:8000

# In another terminal, create test users
for i in {1..20}; do
  curl -X POST http://localhost:8000/users \\
    -H \"Content-Type: application/json\" \\
    -d \"{\\\"name\\\": \\\"TestUser$i\\\"}\"
  echo \"\"
  sleep 1
done

# Create test posts
for i in {1..15}; do
  curl -X POST http://localhost:8000/posts \\
    -H \"Content-Type: application/json\" \\
    -d \"{\\\"user_id\\\": $(( (RANDOM % 20) + 1 )), \\\"content\\\": \\\"Test post $i - This is a test post created for dashboard demonstration\\\"}\"
  echo \"\"
  sleep 2
done
```

**Back in Grafana:**
1. Wait ~15 seconds (for Prometheus to scrape)
2. Refresh your dashboard (click 🔄 or press Ctrl+R)
3. Watch the numbers update!

**What you should see:**
- Total Users: Increased by 20
- Total Posts: Increased by 15
- User Creation Rate: Spike showing activity
- Post Creation Rate: Spike showing activity
- Posts per User: Updated ratio

**Play with time range:**
- Top right: Click time picker
- Select **Last 5 minutes**
- Select **Last 15 minutes**
- Select **Last 1 hour**
- See how the graphs change!

### Step 11: Explore Panel Options

Try customizing your panels:

**Thresholds (Stat panels):**
1. Edit panel (click title → Edit)
2. Scroll to **Thresholds**
3. Add threshold:
   - Base: Green (healthy)
   - `> 100`: Yellow (medium)
   - `> 500`: Red (high)
4. Apply

**Time series styling:**
1. Edit time series panel
2. Try different options:
   - Line style: Solid, Dashed, Dotted
   - Fill opacity: 0-100%
   - Point size: Show data points
   - Gradient mode: Color gradient
3. Apply

**Legend:**
1. Edit panel
2. Scroll to **Legend**
3. Options:
   - Position: Bottom, Right, Hidden
   - Mode: List, Table
   - Show: Min, Max, Average, Current
4. Apply

---

## Troubleshooting

### Issue 1: Grafana Pod Not Starting

**Symptoms:**
```bash
kubectl get pods -l app.kubernetes.io/component=visualization
# NAME                      READY   STATUS             RESTARTS   AGE
# wiki-chart-grafana-xxx    0/1     CrashLoopBackOff   5          10m
```

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod -l app.kubernetes.io/component=visualization

# Check pod logs
kubectl logs -l app.kubernetes.io/component=visualization
```

**Common causes and fixes:**

**A. Database initialization failed:**
```
Error: Failed to initialize SQLite database
Error: mkdir /var/lib/grafana: permission denied
```

**Cause:** Volume permissions incorrect

**Fix:** Ensure security context is set:
```yaml
securityContext:
  fsGroup: 472
  runAsUser: 472
```

**B. Configuration error:**
```
Error: Failed to parse provisioning file
Error: yaml: line 10: mapping values are not allowed
```

**Cause:** Syntax error in datasources ConfigMap

**Fix:** Validate ConfigMap YAML syntax:
```bash
kubectl get configmap wiki-chart-grafana-datasources -o yaml
```

**C. Out of memory:**
```
Error: (killed by OOMKiller)
```

**Cause:** Memory limit too low

**Fix:** Increase memory in values.yaml:
```yaml
grafana:
  resources:
    limits:
      memory: \"1Gi\"  # Increased from 512Mi
```

### Issue 2: Cannot Access Grafana UI

**Symptoms:**
```bash
kubectl port-forward svc/wiki-chart-grafana 3000:3000
# Browser shows: \"Connection refused\"
```

**Diagnosis:**
```bash
# Check if pod is running
kubectl get pods -l app.kubernetes.io/component=visualization

# Check if service exists
kubectl get svc wiki-chart-grafana

# Check service endpoints
kubectl get endpoints wiki-chart-grafana
```

**Common causes and fixes:**

**A. Pod not running:**
```bash
kubectl get pods -l app.kubernetes.io/component=visualization
# No resources found
```

**Fix:** Deploy Grafana:
```bash
helm upgrade --install wiki-chart ./wiki-chart
```

**B. Service has no endpoints:**
```bash
kubectl get endpoints wiki-chart-grafana
# NAME                  ENDPOINTS   AGE
# wiki-chart-grafana    <none>      5m
```

**Cause:** Selector doesn't match pod labels

**Fix:** Verify labels match:
```bash
# Check pod labels
kubectl get pods -l app.kubernetes.io/component=visualization --show-labels

# Check service selector
kubectl get svc wiki-chart-grafana -o yaml | grep -A 5 selector
```

**C. Port-forward to wrong port:**
```bash
# Wrong: Port-forwarding to 8000 instead of 3000
kubectl port-forward svc/wiki-chart-grafana 3000:8000
```

**Fix:** Use correct port:
```bash
kubectl port-forward svc/wiki-chart-grafana 3000:3000
```

### Issue 3: Prometheus Datasource Not Working

**Symptoms:**
In Grafana datasource test:
```
❌ HTTP Error 502: Bad Gateway
❌ Error reading Prometheus
```

**Diagnosis:**
```bash
# 1. Check if Prometheus is running
kubectl get pods -l app.kubernetes.io/component=monitoring

# 2. Check if Prometheus service exists
kubectl get svc wiki-chart-prometheus

# 3. Test connectivity from Grafana pod
kubectl exec -it wiki-chart-grafana-xxx -- \\
  wget -O- http://wiki-chart-prometheus:9090/api/v1/status/config
```

**Common causes and fixes:**

**A. Prometheus not running:**
```bash
kubectl get pods -l app.kubernetes.io/component=monitoring
# No resources found
```

**Fix:** Ensure Prometheus is deployed:
```bash
helm upgrade --install wiki-chart ./wiki-chart
```

**B. Wrong Prometheus URL in datasource:**
```bash
# Check datasource ConfigMap
kubectl get configmap wiki-chart-grafana-datasources -o yaml

# Look for:
# url: http://wiki-chart-prometheus:9090
```

**Fix:** Update ConfigMap if URL is wrong, then restart Grafana:
```bash
kubectl rollout restart deployment wiki-chart-grafana
```

**C. Network policy blocking traffic:**
```bash
# Check for network policies
kubectl get networkpolicies
```

**Fix:** If network policy exists, ensure it allows Grafana → Prometheus traffic.

### Issue 4: Dashboards Lost After Pod Restart

**Symptoms:**
```
Created dashboards are gone after pod restarts
```

**Diagnosis:**
```bash
# Check if PVC is bound
kubectl get pvc wiki-chart-grafana-pvc

# Check if PVC is mounted to pod
kubectl describe pod wiki-chart-grafana-xxx | grep -A 5 \"Volumes:\"
```

**Common causes and fixes:**

**A. PVC not created:**
```bash
kubectl get pvc
# No PVC named wiki-chart-grafana-pvc
```

**Fix:** Ensure PVC is in Helm chart:
```bash
helm template wiki-chart ./wiki-chart | grep -A 10 \"kind: PersistentVolumeClaim\"
```

**B. PVC not mounted:**
```bash
kubectl describe pod wiki-chart-grafana-xxx
# No volume mount at /var/lib/grafana
```

**Fix:** Check deployment volume mounts:
```yaml
volumeMounts:
- name: storage
  mountPath: /var/lib/grafana
```

**C. Wrong mount path:**
Grafana expects data at `/var/lib/grafana`, ensure mount path is correct.

### Issue 5: No Metrics Showing in Dashboard

**Symptoms:**
```
Dashboard panels show: \"No data\"
Query returns empty result
```

**Diagnosis:**
```bash
# 1. Check if Prometheus has data
kubectl port-forward svc/wiki-chart-prometheus 9090:9090
# Open http://localhost:9090 and query: users_created_total

# 2. Check if FastAPI is exposing metrics
kubectl port-forward svc/wiki-chart-fastapi 8000:8000
# Open http://localhost:8000/metrics
```

**Common causes and fixes:**

**A. No metrics generated yet:**
```
Prometheus has data, but value is 0
```

**Fix:** Generate test traffic (create users/posts) to increment counters.

**B. Wrong query:**
```
Query: user_created_total  # Wrong
Correct: users_created_total  # Note the 's'
```

**Fix:** Verify metric name in Prometheus:
```
1. Open Prometheus UI
2. Go to Status → Targets
3. Click on fastapi target
4. See actual metric names
```

**C. Time range issue:**
```
Dashboard time range: Last 5 minutes
Metrics only available from 2 hours ago
```

**Fix:** Adjust time range:
```
Top right → Time picker → Last 6 hours
```

**D. Datasource not selected:**
```
Panel query shows: (no datasource)
```

**Fix:** Select Prometheus datasource in panel query editor.

### Issue 6: Login Credentials Not Working

**Symptoms:**
```
Login page shows: \"Invalid username or password\"
Using admin/admin doesn't work
```

**Diagnosis:**
```bash
# Check environment variables in pod
kubectl exec -it wiki-chart-grafana-xxx -- env | grep GF_SECURITY
```

**Expected:**
```
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin
```

**Common causes and fixes:**

**A. Environment variables not set:**
```bash
# No GF_SECURITY_ADMIN_* variables
```

**Fix:** Check deployment env section:
```yaml
env:
- name: GF_SECURITY_ADMIN_USER
  value: {{ .Values.grafana.adminUser | quote }}
- name: GF_SECURITY_ADMIN_PASSWORD
  value: {{ .Values.grafana.adminPassword | quote }}
```

**B. Wrong values in values.yaml:**
```yaml
grafana:
  adminUser: \"admin\"
  adminPassword: \"wrong-password\"  # Changed from \"admin\"
```

**Fix:** Use credentials from values.yaml, or reset:
```bash
# Update values.yaml, then:
helm upgrade --install wiki-chart ./wiki-chart
kubectl rollout restart deployment wiki-chart-grafana
```

**C. First-time setup already completed:**
If you've changed password in Grafana UI, it's stored in database. Environment variables only work for initial setup.

**Fix:** Reset database by deleting PVC (⚠️ loses all dashboards):
```bash
kubectl delete pvc wiki-chart-grafana-pvc
kubectl delete pod -l app.kubernetes.io/component=visualization
# Wait for pod to recreate with fresh database
```

---

## Best Practices and Production Considerations

### 1. Security Hardening

#### Use Secrets for Credentials

**Current setup (development):**
```yaml
# values.yaml
grafana:
  adminPassword: admin  # PLAIN TEXT! ❌
```

**Production setup:**
```yaml
# 1. Create Secret
apiVersion: v1
kind: Secret
metadata:
  name: grafana-credentials
type: Opaque
stringData:
  admin-user: admin
  admin-password: <strong-password>  # Generate with: openssl rand -base64 32

# 2. Reference in Deployment
env:
- name: GF_SECURITY_ADMIN_USER
  valueFrom:
    secretKeyRef:
      name: grafana-credentials
      key: admin-user
- name: GF_SECURITY_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: grafana-credentials
      key: admin-password
```

**Benefits:**
- Credentials not in Git
- Separate permission model (Secret RBAC)
- Easier credential rotation

#### Enable Authentication

**Options:**

**1. Built-in users:**
```yaml
# Grafana UI: Configuration → Users
# Create additional users with different roles:
# - Admin: Full control
# - Editor: Create/edit dashboards
# - Viewer: Read-only access
```

**2. LDAP/Active Directory:**
```yaml
# Environment variables
- name: GF_AUTH_LDAP_ENABLED
  value: \"true\"
- name: GF_AUTH_LDAP_CONFIG_FILE
  value: \"/etc/grafana/ldap.toml\"
```

**3. OAuth (Google, GitHub, GitLab):**
```yaml
# For GitHub OAuth
- name: GF_AUTH_GITHUB_ENABLED
  value: \"true\"
- name: GF_AUTH_GITHUB_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: github-oauth
      key: client-id
- name: GF_AUTH_GITHUB_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: github-oauth
      key: client-secret
```

**4. Proxy authentication (SSO):**
Use Ingress with auth proxy (OAuth2 Proxy, Authelia, etc.)

#### Disable Anonymous Access

```yaml
env:
- name: GF_AUTH_ANONYMOUS_ENABLED
  value: \"false\"
```

**Default:** Anonymous access is disabled. Keep it that way!

### 2. High Availability Setup

For production with high availability requirements:

#### External Database

**Current setup:**
```yaml
- name: GF_DATABASE_TYPE
  value: sqlite3  # ❌ Single instance only
```

**HA setup:**
```yaml
# Use PostgreSQL (reuse existing database)
- name: GF_DATABASE_TYPE
  value: postgres
- name: GF_DATABASE_HOST
  value: postgres-service:5432
- name: GF_DATABASE_NAME
  value: grafana
- name: GF_DATABASE_USER
  valueFrom:
    secretKeyRef:
      name: grafana-db-credentials
      key: username
- name: GF_DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: grafana-db-credentials
      key: password
```

**Benefits:**
- Multiple Grafana replicas
- Better performance under load
- Professional setup

**Setup steps:**
```sql
-- 1. Create database
CREATE DATABASE grafana;

-- 2. Create user
CREATE USER grafana WITH PASSWORD 'secure-password';

-- 3. Grant permissions
GRANT ALL PRIVILEGES ON DATABASE grafana TO grafana;
```

#### Multiple Replicas

```yaml
# values.yaml
grafana:
  replicaCount: 3  # Run 3 Grafana instances

# Update PVC access mode (only if using external DB)
persistence:
  # Remove: accessMode: ReadWriteOnce
  # No PVC needed with external DB (stateless)
  enabled: false
```

**With external database:**
```
User Request
    ↓
Service (Load Balancer)
    ↓
   ├─→ Grafana Pod 1 ─┐
   ├─→ Grafana Pod 2 ─┼→ PostgreSQL Database
   └─→ Grafana Pod 3 ─┘
```

**Benefits:**
- No single point of failure
- Handle more concurrent users
- Zero-downtime deployments

### 3. Backup and Recovery

#### Dashboard Backup

**Option 1: Manual export**
```
1. Open dashboard
2. Click ⚙️ (settings)
3. Click \"JSON Model\"
4. Copy JSON
5. Save to Git repository
```

**Option 2: API export**
```bash
#!/bin/bash
# Export all dashboards via API

GRAFANA_URL=\"http://localhost:3000\"
API_KEY=\"your-api-key\"  # Create in Grafana: Configuration → API Keys

# Get all dashboard UIDs
curl -H \"Authorization: Bearer $API_KEY\" \\
  \"$GRAFANA_URL/api/search?type=dash-db\" \\
  | jq -r '.[].uid' \\
  > dashboard_uids.txt

# Export each dashboard
while read uid; do
  curl -H \"Authorization: Bearer $API_KEY\" \\
    \"$GRAFANA_URL/api/dashboards/uid/$uid\" \\
    | jq '.dashboard' \\
    > \"dashboard-$uid.json\"
done < dashboard_uids.txt
```

**Option 3: PVC snapshots**
```bash
# If your storage provider supports snapshots
kubectl create volumesnapshot grafana-backup \\
  --source-pvc=wiki-chart-grafana-pvc
```

#### Dashboard Provisioning

**Best practice:** Store dashboards in Git as JSON files

```yaml
# 1. Create ConfigMap with dashboard JSON
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
data:
  fastapi-dashboard.json: |
    {
      \"dashboard\": {
        \"title\": \"FastAPI Monitoring\",
        \"panels\": [...]
      }
    }

# 2. Mount to provisioning directory
volumeMounts:
- name: dashboards
  mountPath: /etc/grafana/provisioning/dashboards

volumes:
- name: dashboards
  configMap:
    name: grafana-dashboards
```

**Benefits:**
- Dashboards in Git (version control)
- Automatic provisioning
- Consistent across environments
- Easy rollback

### 4. Performance Optimization

#### Query Performance

**Problem:** Slow dashboard load times

**Solutions:**

**1. Reduce query time range:**
```
Instead of: Last 30 days
Use: Last 24 hours (with option to zoom out)
```

**2. Increase step interval:**
```promql
# Instead of 15s resolution:
rate(users_created_total[5m])

# Use 1m resolution:
rate(users_created_total[5m])[1m]
```

**3. Use recording rules in Prometheus:**
```yaml
# Pre-calculate expensive queries
groups:
- name: grafana_optimization
  interval: 60s
  rules:
  - record: user_creation_rate_1m
    expr: rate(users_created_total[5m]) * 60
```

Then in Grafana, query the pre-calculated metric:
```promql
user_creation_rate_1m
```

**4. Enable query caching:**
```yaml
env:
- name: GF_DATAPROXY_TIMEOUT
  value: \"30\"  # Query timeout (seconds)
- name: GF_DATAPROXY_MAX_IDLE_CONNECTIONS
  value: \"100\"
```

#### Dashboard Performance

**Best practices:**
1. **Limit panels**: 10-15 panels per dashboard (more = slower load)
2. **Avoid auto-refresh on long time ranges**: Auto-refresh every 5s on 7-day range is wasteful
3. **Use appropriate visualization**: Table with 10k rows = slow, use time series instead
4. **Set max data points**: Limit data points per series (e.g., 1000 max)

### 5. Monitoring Grafana Itself

#### Grafana Metrics

Grafana exposes its own metrics at `/metrics`:

```bash
kubectl port-forward svc/wiki-chart-grafana 3000:3000
curl http://localhost:3000/metrics
```

**Key metrics to monitor:**
```
# HTTP requests
grafana_http_request_duration_seconds
grafana_http_request_total

# Database
grafana_database_* (connection pool, query duration)

# Alerting
grafana_alerting_* (alert evaluations, notifications)

# Users
grafana_active_users
grafana_user_logins_total
```

**Add Grafana to Prometheus targets:**
```yaml
# prometheus-configmap.yaml
scrape_configs:
- job_name: 'grafana'
  static_configs:
    - targets: ['wiki-chart-grafana:3000']
  metrics_path: '/metrics'
```

**Then create dashboard to monitor Grafana!** (Meta-monitoring 🎭)

### 6. Cost Optimization

#### Resource Right-Sizing

**Monitor actual usage:**
```bash
kubectl top pod wiki-chart-grafana-xxx

# Example output:
# NAME                      CPU(cores)   MEMORY(bytes)
# wiki-chart-grafana-xxx    50m          180Mi
```

**If consistently under-utilized:**
```yaml
# Reduce resources
grafana:
  resources:
    requests:
      cpu: 50m       # Reduced from 100m
      memory: 128Mi  # Keep same
    limits:
      cpu: 250m      # Reduced from 500m
      memory: 256Mi  # Reduced from 512Mi
```

**Benefits:**
- Lower cloud costs
- Better node packing
- Faster scheduling

#### Storage Optimization

**Monitor storage usage:**
```bash
kubectl exec -it wiki-chart-grafana-xxx -- du -sh /var/lib/grafana/*

# Example output:
# 12M   /var/lib/grafana/grafana.db
# 4.0K  /var/lib/grafana/plugins
# 256K  /var/lib/grafana/png
```

**If well under 1Gi:**
Consider reducing PVC size (requires recreating PVC):
```yaml
grafana:
  persistence:
    size: 500Mi  # Reduced from 1Gi
```

### 7. Compliance and Auditing

#### Enable Audit Logging

```yaml
env:
- name: GF_LOG_LEVEL
  value: \"info\"
- name: GF_AUDITING_ENABLED
  value: \"true\"
- name: GF_AUDITING_LOG_BACKEND
  value: \"file\"
- name: GF_AUDITING_LOG_PATH
  value: \"/var/log/grafana/audit.log\"
```

**Audit log captures:**
- User logins/logouts
- Dashboard creations/edits/deletions
- Datasource changes
- Permission changes
- API calls

#### Log Forwarding

Forward logs to centralized logging (ELK, Loki, Splunk):

**Example with Loki:**
```yaml
env:
- name: GF_LOG_MODE
  value: \"console,loki\"
- name: GF_LOG_LOKI_URL
  value: \"http://loki:3100\"
```

### 8. Update Strategy

#### Zero-Downtime Updates

**Current setup:** Single replica = brief downtime during upgrade

**HA setup with rolling update:**
```yaml
# Deployment strategy
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # 1 extra pod during update
      maxUnavailable: 0  # Always 3 pods available
```

**Update process:**
```
Initial: [v1] [v1] [v1]
Step 1:  [v1] [v1] [v1] [v2]  ← New pod created
Step 2:  [v1] [v1] [v2]        ← Old pod terminated
Step 3:  [v1] [v1] [v2] [v2]  ← New pod created
Step 4:  [v1] [v2] [v2]        ← Old pod terminated
Step 5:  [v1] [v2] [v2] [v2]  ← New pod created
Step 6:  [v2] [v2] [v2]        ← All updated!
```

**Result:** Users never experience downtime!

#### Version Pinning

**Current:**
```yaml
image:
  tag: \"10.2.3\"  # ✅ Specific version
```

**Avoid:**
```yaml
image:
  tag: \"latest\"  # ❌ Unpredictable updates
```

**Why:**
- Reproducible builds
- Controlled upgrades
- Easier rollback

---

## Next Steps

### Phase 9: Ingress Configuration (Preview)

Now that Grafana is running internally, Phase 9 will expose it externally via Ingress.

**What we'll implement:**
- Ingress Controller (NGINX)
- Ingress resource for routing
- TLS/HTTPS certificates (optional)
- Path-based routing

**Ingress will enable:**
```
Internet
    ↓
Ingress (NGINX)
    ↓
   ├─→ / → FastAPI Service (API endpoints)
   ├─→ /grafana → Grafana Service (dashboards)
   └─→ /prometheus → Prometheus Service (metrics API)
```

**External access:**
```
http://wiki-api.local/           → FastAPI
http://wiki-api.local/grafana    → Grafana
http://wiki-api.local/prometheus → Prometheus
```

**Benefits:**
- Single entry point for all services
- SSL/TLS termination
- Load balancing
- Authentication at edge
- Domain-based routing

### Beyond Phase 9: Advanced Topics

**Phase 10: Alerting**
- Prometheus alert rules
- Alertmanager deployment
- Grafana alert notifications
- PagerDuty/Slack integration

**Phase 11: Advanced Monitoring**
- Service mesh (Istio/Linkerd)
- Distributed tracing (Jaeger, Tempo)
- Log aggregation (Loki)
- Unified observability

**Phase 12: GitOps**
- ArgoCD for deployment automation
- Git as source of truth
- Automated rollbacks
- Multi-environment management

---

## Summary

**What we accomplished in Phase 8:**
1. ✅ Deployed Grafana visualization server
2. ✅ Configured persistent storage for dashboards
3. ✅ Auto-provisioned Prometheus datasource
4. ✅ Created interactive dashboard
5. ✅ Enabled real-time monitoring

**Key learnings:**
- **Grafana** transforms raw metrics into actionable insights
- **Datasources** connect Grafana to data sources like Prometheus
- **Dashboards** tell stories with data through visualizations
- **Persistence** ensures dashboards survive pod restarts
- **Auto-provisioning** enables Infrastructure as Code

**Observability stack complete:**
```
FastAPI (metrics) → Prometheus (storage) → Grafana (visualization)
```

**You can now:**
- Monitor application health in real-time
- Track user and post creation trends
- Create custom dashboards for your team
- Make data-driven decisions
- Detect and diagnose issues faster

**Next:** Phase 9 will expose Grafana externally via Ingress for team access! 🚀

---

**Questions or issues?** Review the troubleshooting section or check Grafana logs:
```bash
kubectl logs -l app.kubernetes.io/component=visualization --tail=100
```

**Happy visualizing! 📊📈✨**
