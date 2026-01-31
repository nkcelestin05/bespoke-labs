# Phase 7: Prometheus Monitoring Deployment - Implementation Plan

## 📋 Executive Summary

Based on comprehensive analysis of Phases 1-6, **Phase 7 should focus on implementing Prometheus monitoring** to enable observability of the FastAPI application. This phase will create the necessary Kubernetes resources to deploy Prometheus, configure metric scraping, and establish the monitoring foundation that will enable Grafana dashboards in Phase 8.

---

## 🔍 Analysis of Previous Phases

### Phase Progression Overview

| Phase | Focus Area | Key Deliverables | Type |
|-------|-----------|------------------|------|
| **Phase 1** | Foundation | Project structure, FastAPI with SQLite | Setup |
| **Phase 2** | Database Migration | SQLite → PostgreSQL, environment variables | Application |
| **Phase 3** | Containerization | Dockerfile, Docker best practices | Infrastructure |
| **Phase 4** | Helm Foundation | Chart.yaml, values.yaml, directory structure | Infrastructure |
| **Phase 5** | Database Deployment | PostgreSQL K8s resources (PVC, Deployment, Service) | Infrastructure |
| **Phase 6** | API Deployment | FastAPI K8s resources (Deployment, Service, Init containers) | Infrastructure |

### Identified Patterns

1. **Alternating Focus**: Phases alternate between application-layer changes (2) and infrastructure-layer changes (3, 4, 5, 6)

2. **Building Block Approach**: Each phase builds directly on the previous one:
   - Phase 2 → 3: Database changes → Containerize
   - Phase 4 → 5 → 6: Helm structure → Database deployment → API deployment

3. **Educational Documentation**: Each phase includes:
   - Detailed concept explanations
   - Line-by-line code/YAML walkthroughs
   - Troubleshooting guides
   - Visual diagrams
   - Best practices

4. **Production Readiness**: Consistent focus on:
   - Security (non-root users, secrets management)
   - Reliability (health probes, resource limits)
   - Scalability (multiple replicas, proper resource management)

### Current State Analysis

#### ✅ What's Complete

**Application Layer:**
- FastAPI application with CRUD operations for Users and Posts
- PostgreSQL database integration with async SQLAlchemy
- Prometheus client library integrated
- `/metrics` endpoint exposing custom counters:
  - `users_created_total`
  - `posts_created_total`
- Database connection via environment variables

**Infrastructure Layer:**
- Dockerfile with security hardening (non-root user, multi-stage concepts)
- Helm chart structure (Chart.yaml, values.yaml)
- PostgreSQL Kubernetes resources:
  - PersistentVolumeClaim (data persistence)
  - Deployment (database pods)
  - Service (internal networking)
- FastAPI Kubernetes resources:
  - Deployment (2 replicas, init containers, health probes)
  - Service (ClusterIP, load balancing)

**Configuration:**
- `values.yaml` includes comprehensive configuration for:
  - FastAPI ✅ (implemented)
  - PostgreSQL ✅ (implemented)
  - **Prometheus** 🔄 (configured but not deployed)
  - **Grafana** 🔄 (configured but not deployed)
  - **Ingress** 🔄 (configured but not deployed)

#### 🔄 What's Missing

**Prometheus Resources** (needed for Phase 7):
- `prometheus-configmap.yaml` - Scrape configuration
- `prometheus-pvc.yaml` - Persistent storage for metrics data
- `prometheus-deployment.yaml` - Prometheus server deployment
- `prometheus-service.yaml` - Internal service for Grafana to query

**Grafana Resources** (Phase 8):
- Deployment, ConfigMap, Service, PVC

**Ingress Resources** (Phase 9):
- Ingress manifest for external access

**Application Enhancements** (Minor):
- Missing `/health` endpoint (referenced in health probes but not implemented)

---

## 🎯 Phase 7: Prometheus Monitoring - Scope and Goals

### Primary Objectives

1. **Deploy Prometheus** to the Kubernetes cluster
2. **Configure metric collection** from FastAPI `/metrics` endpoint
3. **Enable persistent storage** for time-series metrics data
4. **Prepare monitoring foundation** for Grafana visualization (Phase 8)

### Success Criteria

- ✅ Prometheus pod running and healthy
- ✅ Prometheus successfully scraping FastAPI metrics every 15 seconds
- ✅ Metrics data persisting across pod restarts (via PVC)
- ✅ Prometheus web UI accessible within cluster
- ✅ Self-monitoring enabled (Prometheus monitoring itself)
- ✅ Templates follow established patterns and documentation quality

### Out of Scope (Reserved for Later Phases)

- ❌ Grafana deployment (Phase 8)
- ❌ Grafana dashboard creation (Phase 8)
- ❌ External access via Ingress (Phase 9)
- ❌ Alerting rules (Phase 10+)

---

## 📦 Deliverables

### 1. Kubernetes Templates to Create

#### `wiki-chart/templates/prometheus-configmap.yaml`

**Purpose**: Define Prometheus scrape configuration and global settings

**Key Components**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "wiki-chart.fullname" . }}-prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: {{ .Values.prometheus.scrapeInterval }}
      evaluation_interval: {{ .Values.prometheus.evaluationInterval }}
    
    scrape_configs:
      # Scrape FastAPI application metrics
      - job_name: 'fastapi'
        static_configs:
          - targets: ['{{ include "wiki-chart.fullname" . }}-fastapi:8000']
        metrics_path: '/metrics'
      
      # Self-monitoring
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
```

**Configuration Explanation**:
- `scrape_interval`: How often to scrape targets (15s default)
- `evaluation_interval`: How often to evaluate recording rules (15s default)
- `job_name: 'fastapi'`: Scrapes the FastAPI service on port 8000
- `metrics_path: '/metrics'`: Endpoint where Prometheus metrics are exposed
- Self-monitoring: Prometheus monitors its own health

#### `wiki-chart/templates/prometheus-pvc.yaml`

**Purpose**: Request persistent storage for Prometheus time-series database

**Key Components**:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "wiki-chart.fullname" . }}-prometheus-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: {{ .Values.prometheus.persistence.storageClass }}
  resources:
    requests:
      storage: {{ .Values.prometheus.persistence.size }}
```

**Why Persistence Matters**:
- Without PVC: Metrics lost on pod restart, historical data gone
- With PVC: Metrics persist, enabling trend analysis over time
- Default size: 2Gi (configurable in values.yaml)

#### `wiki-chart/templates/prometheus-deployment.yaml`

**Purpose**: Manage Prometheus server pods

**Key Components**:

1. **Volume Mounts**:
   - Config volume: `/etc/prometheus/prometheus.yml` (from ConfigMap)
   - Data volume: `/prometheus` (from PVC)

2. **Startup Arguments**:
   ```yaml
   args:
     - '--config.file=/etc/prometheus/prometheus.yml'
     - '--storage.tsdb.path=/prometheus'
     - '--storage.tsdb.retention.time=15d'
     - '--web.enable-lifecycle'
   ```
   - `--config.file`: Path to configuration file
   - `--storage.tsdb.path`: Where to store metrics data
   - `--storage.tsdb.retention.time`: Keep 15 days of metrics
   - `--web.enable-lifecycle`: Allow config reload via API

3. **Health Probes**:
   - Liveness: Check if Prometheus is running (`/-/healthy`)
   - Readiness: Check if Prometheus is ready to serve queries (`/-/ready`)

4. **Resource Limits**:
   ```yaml
   resources:
     requests:
       cpu: 100m
       memory: 256Mi
     limits:
       cpu: 500m
       memory: 1Gi
   ```

#### `wiki-chart/templates/prometheus-service.yaml`

**Purpose**: Provide stable internal networking for Prometheus

**Key Components**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "wiki-chart.fullname" . }}-prometheus
spec:
  type: ClusterIP
  ports:
    - port: 9090
      targetPort: 9090
      protocol: TCP
      name: web
  selector:
    app.kubernetes.io/component: monitoring
```

**Why ClusterIP**:
- Internal access only (Grafana will query this service)
- External access via Ingress in Phase 9
- More secure than exposing directly

### 2. Documentation to Create

#### `PHASE7_PROMETHEUS.md`

Following the established documentation pattern, this file should include:

**Section Structure**:
1. **Overview** - What Phase 7 accomplishes
2. **What is Prometheus?** - Educational introduction
   - Time-series database concept
   - Pull-based metrics collection
   - Use cases for monitoring
3. **ConfigMap Explained** - Line-by-line breakdown
   - Scrape configuration
   - Target discovery
   - Metrics path
4. **PVC Explained** - Persistence deep dive
   - Why Prometheus needs storage
   - TSDB (Time Series Database) architecture
   - Retention policies
5. **Deployment Explained** - Component details
   - Volume mounting strategy
   - Prometheus arguments and flags
   - Health probe configuration
   - Resource management
6. **Service Explained** - Networking concepts
   - ClusterIP for internal access
   - Port configuration
   - Service discovery
7. **How Values Are Templated** - Helm templating examples
8. **Testing the Deployment** - Validation steps
   - `helm template` preview
   - Deployment verification
   - Accessing Prometheus UI (port-forward)
   - Verifying metric scraping
9. **Troubleshooting** - Common issues and solutions
   - Scrape target down
   - Permission issues
   - Storage problems
10. **Next Steps: Phase 8** - Preview of Grafana integration

### 3. values.yaml Updates (Optional)

The `values.yaml` already has comprehensive Prometheus configuration. Minor additions could include:

```yaml
prometheus:
  # ... existing configuration ...
  
  # Retention policy
  retention:
    time: 15d  # Keep metrics for 15 days
    size: 1GB  # Max storage before cleanup
  
  # Enable web console
  webConsole:
    enabled: true
```

---

## 🔧 Technical Implementation Details

### Prometheus Scraping Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                     │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Prometheus Pod                                     │ │
│  │                                                    │ │
│  │  ┌──────────────────────────────────────────┐   │ │
│  │  │ Prometheus Server                        │   │ │
│  │  │ - Scrapes metrics every 15s              │   │ │
│  │  │ - Stores in TSDB                         │   │ │
│  │  │ - Web UI on :9090                        │   │ │
│  │  └──────────────────────────────────────────┘   │ │
│  │         │                        │               │ │
│  │         │ Volume Mounts          │               │ │
│  │         ↓                        ↓               │ │
│  │  ┌─────────────┐         ┌─────────────┐       │ │
│  │  │ ConfigMap   │         │ PVC         │       │ │
│  │  │ (Config)    │         │ (Data)      │       │ │
│  │  └─────────────┘         └─────────────┘       │ │
│  └────────────────────────────────────────────────────┘ │
│                        ↓ Scrapes                          │
│                        ↓                                  │
│  ┌────────────────────────────────────────────────────┐ │
│  │ FastAPI Service                                    │ │
│  │ - Exposes /metrics on :8000                        │ │
│  │ - Returns Prometheus format metrics                │ │
│  │                                                    │ │
│  │  Metrics Exposed:                                  │ │
│  │  - users_created_total                             │ │
│  │  - posts_created_total                             │ │
│  │  - (plus Python runtime metrics)                   │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

### Metrics Flow

1. **Scraping**:
   - Prometheus makes HTTP GET request to `http://fastapi-service:8000/metrics`
   - FastAPI responds with metrics in Prometheus text format
   - Example metric: `users_created_total{} 42`

2. **Storage**:
   - Prometheus stores metrics in TSDB at `/prometheus`
   - Data persists on PVC
   - Retention: 15 days (configurable)

3. **Querying** (Phase 8):
   - Grafana queries Prometheus via `http://prometheus-service:9090`
   - Uses PromQL (Prometheus Query Language)
   - Example query: `rate(users_created_total[5m])`

### Security Considerations

1. **Cluster-Internal Only**:
   - ClusterIP service (not exposed externally)
   - Ingress will provide controlled external access (Phase 9)

2. **No Authentication** (Development):
   - Current setup has no authentication
   - Production should add basic auth or OAuth

3. **Secrets Management**:
   - No sensitive data in ConfigMap
   - Future: Use Secrets for auth credentials

### Resource Planning

**Prometheus Resource Usage**:
- **CPU**: 100m (normal) → 500m (peaks during scraping)
- **Memory**: 256Mi (normal) → 1Gi (max limit)
- **Storage**: 2Gi (sufficient for 15 days at 15s intervals)

**Capacity Planning**:
- Metrics per scrape: ~50 metrics
- Scrape interval: 15s
- Data points per day: 50 metrics × 4 scrapes/min × 1440 min = 288,000 points
- Storage per day: ~50MB (compressed)
- 15-day retention: ~750MB (fits in 2Gi with buffer)

---

## 🧪 Testing & Validation Plan

### Pre-Deployment Validation

```bash
# 1. Validate Helm syntax
helm lint ./wiki-chart

# 2. Render templates to check output
helm template wiki-chart ./wiki-chart > /tmp/rendered.yaml

# 3. Check for Prometheus resources
grep -A 10 "kind: ConfigMap" /tmp/rendered.yaml
grep -A 10 "kind: PersistentVolumeClaim" /tmp/rendered.yaml

# 4. Validate YAML syntax
kubectl apply --dry-run=client -f /tmp/rendered.yaml
```

### Deployment Validation

```bash
# 1. Install/upgrade the chart
helm upgrade --install wiki-chart ./wiki-chart

# 2. Verify Prometheus pod is running
kubectl get pods -l app.kubernetes.io/component=monitoring
# Expected: wiki-chart-prometheus-xxxxx   1/1   Running

# 3. Check PVC is bound
kubectl get pvc
# Expected: wiki-chart-prometheus-pvc   Bound

# 4. View Prometheus logs
kubectl logs -l app.kubernetes.io/component=monitoring

# 5. Port-forward to access UI
kubectl port-forward svc/wiki-chart-prometheus 9090:9090
# Open browser: http://localhost:9090
```

### Functional Validation

**In Prometheus UI** (http://localhost:9090):

1. **Check Targets**:
   - Navigate to Status → Targets
   - Verify `fastapi` target is UP
   - Check last scrape time (should be < 15s ago)

2. **Query Metrics**:
   - Go to Graph tab
   - Query: `users_created_total`
   - Should return current value
   - Create a test user via API, verify counter increments

3. **Check Self-Monitoring**:
   - Query: `prometheus_build_info`
   - Should return Prometheus version info

### Load Testing

```bash
# Generate some traffic to create metrics
for i in {1..10}; do
  curl -X POST http://localhost:8000/users \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"User$i\"}"
done

# Query in Prometheus:
# users_created_total should show 10+
```

---

## 🔄 Integration with Existing Components

### Connection to FastAPI (Phase 6)

**Existing Setup**:
- FastAPI exposes `/metrics` endpoint (Phase 1, enhanced in Phase 2)
- Service name: `wiki-chart-fastapi`
- Port: 8000

**Phase 7 Integration**:
- Prometheus scrapes `wiki-chart-fastapi:8000/metrics`
- No changes needed to FastAPI application
- Automatic metric discovery via service name

### Preparation for Grafana (Phase 8)

**What Phase 7 Provides**:
- Prometheus service endpoint: `wiki-chart-prometheus:9090`
- Metrics available via PromQL queries
- Time-series data for dashboard visualization

**What Phase 8 Will Do**:
- Deploy Grafana
- Configure Prometheus as datasource
- Create dashboards to visualize metrics

### values.yaml Consistency

All configuration follows existing patterns:
```yaml
prometheus:
  image:        # Same structure as fastapi.image
  service:      # Same structure as fastapi.service
  resources:    # Same structure as fastapi.resources
  persistence:  # Same structure as postgresql.persistence
```

---

## 📚 Educational Value

Phase 7 continues the project's educational mission by teaching:

### Monitoring Concepts

1. **Observability Fundamentals**:
   - What is observability vs. monitoring
   - The three pillars: Metrics, Logs, Traces
   - Why metrics matter for production systems

2. **Prometheus Architecture**:
   - Pull-based vs. push-based metrics
   - Time-series database concepts
   - TSDB data model (labels, samples, series)

3. **Metric Types**:
   - Counter (monotonically increasing)
   - Gauge (can go up and down)
   - Histogram (distributions)
   - Summary (client-side quantiles)

### Kubernetes Concepts Reinforced

1. **ConfigMaps**:
   - Storing configuration as data
   - Mounting as files vs. environment variables
   - When to use ConfigMap vs. Secret

2. **Persistent Storage**:
   - StatefulSet vs. Deployment with PVC
   - Retention policies and disk management
   - Storage classes and provisioners

3. **Service Discovery**:
   - How Prometheus finds targets
   - DNS-based service discovery in Kubernetes
   - Labels and selectors for targeting

---

## ⚠️ Potential Challenges & Solutions

### Challenge 1: Scrape Target Not Found

**Symptom**: Prometheus shows FastAPI target as DOWN

**Possible Causes**:
- Service name mismatch
- FastAPI pods not ready
- Network policies blocking traffic

**Solution**:
```bash
# Verify service exists
kubectl get svc wiki-chart-fastapi

# Test connectivity from Prometheus pod
kubectl exec -it wiki-chart-prometheus-xxxxx -- \
  wget -O- http://wiki-chart-fastapi:8000/metrics
```

### Challenge 2: PVC Pending

**Symptom**: PVC stuck in Pending state

**Possible Causes**:
- No default storage class
- Storage class doesn't exist
- No available storage

**Solution**:
```bash
# Check storage classes
kubectl get storageclass

# Check PVC events
kubectl describe pvc wiki-chart-prometheus-pvc

# If needed, specify different storage class in values.yaml
```

### Challenge 3: High Memory Usage

**Symptom**: Prometheus pod OOMKilled

**Possible Causes**:
- Too many metrics
- Long retention time
- Memory limit too low

**Solution**:
```yaml
# Adjust in values.yaml
prometheus:
  resources:
    limits:
      memory: "2Gi"  # Increase from 1Gi
  
  retention:
    time: 7d  # Reduce from 15d if needed
```

### Challenge 4: Missing `/health` Endpoint

**Symptom**: FastAPI health probes failing (noted during analysis)

**Impact**: Health checks reference `/health` but endpoint doesn't exist

**Solution** (Quick fix for Phase 7):
```python
# Add to wiki-service/app/main.py
@app.get("/health")
async def health_check():
    """Health check endpoint for Kubernetes probes."""
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}
```

---

## 📋 Implementation Checklist

### Template Creation

- [ ] Create `templates/prometheus-configmap.yaml`
  - [ ] Define global scrape configuration
  - [ ] Add FastAPI scrape target
  - [ ] Add self-monitoring scrape target
  - [ ] Use Helm templating for service names
  - [ ] Add comprehensive comments

- [ ] Create `templates/prometheus-pvc.yaml`
  - [ ] Request 2Gi storage (configurable)
  - [ ] Use ReadWriteOnce access mode
  - [ ] Reference values.yaml for storageClass
  - [ ] Add comprehensive comments

- [ ] Create `templates/prometheus-deployment.yaml`
  - [ ] Single replica (TSDB doesn't support clustering)
  - [ ] Mount ConfigMap as config file
  - [ ] Mount PVC for data storage
  - [ ] Configure startup arguments
  - [ ] Add liveness probe (`/-/healthy`)
  - [ ] Add readiness probe (`/-/ready`)
  - [ ] Set resource requests and limits
  - [ ] Use proper labels and selectors
  - [ ] Add comprehensive comments

- [ ] Create `templates/prometheus-service.yaml`
  - [ ] ClusterIP service type
  - [ ] Port 9090
  - [ ] Proper selectors matching deployment
  - [ ] Add comprehensive comments

### Documentation

- [ ] Create `PHASE7_PROMETHEUS.md`
  - [ ] Overview section
  - [ ] "What is Prometheus?" educational content
  - [ ] ConfigMap deep dive
  - [ ] PVC explanation with diagrams
  - [ ] Deployment explanation
  - [ ] Service explanation
  - [ ] Testing procedures
  - [ ] Troubleshooting guide
  - [ ] Next steps preview (Phase 8)

- [ ] Update `README.md`
  - [ ] Mark Phase 7 as complete
  - [ ] Update project status
  - [ ] Update architecture diagram (if present)

### Optional Enhancements

- [ ] Add `/health` endpoint to FastAPI application
- [ ] Enhance `metrics.py` with additional counters
- [ ] Add retention policy configuration to values.yaml
- [ ] Create helper template for Prometheus config

### Testing & Validation

- [ ] Run `helm lint ./wiki-chart`
- [ ] Run `helm template ./wiki-chart` and verify output
- [ ] Deploy to test cluster
- [ ] Verify Prometheus pod starts
- [ ] Verify PVC is bound
- [ ] Access Prometheus UI via port-forward
- [ ] Verify FastAPI target is scraped successfully
- [ ] Generate test traffic and verify metrics update
- [ ] Test pod restart (verify metrics persist)

---

## 🎓 Learning Outcomes

After completing Phase 7, students/users will understand:

1. **Monitoring Best Practices**:
   - Why observability matters in production
   - How to instrument applications for monitoring
   - Metric collection patterns

2. **Prometheus Fundamentals**:
   - Architecture and data model
   - Scrape configuration
   - PromQL basics (querying)

3. **Kubernetes Patterns**:
   - ConfigMap for application configuration
   - Persistent storage with PVCs
   - Service discovery and networking

4. **Production Readiness**:
   - Health checks for monitoring systems
   - Resource management for data-intensive apps
   - Data retention policies

---

## 🚀 Phase 8 Preview

Phase 8 will build on Phase 7 by adding **Grafana for visualization**:

### Phase 8 Scope

1. **Grafana Deployment**:
   - `grafana-deployment.yaml`
   - `grafana-service.yaml`
   - `grafana-pvc.yaml`

2. **Grafana Configuration**:
   - `grafana-datasource-configmap.yaml` (auto-configure Prometheus)
   - `grafana-dashboards-configmap.yaml` (pre-built dashboards)

3. **Dashboards**:
   - FastAPI performance dashboard
   - Resource usage dashboard
   - Custom metrics dashboard

4. **Integration**:
   - Grafana connects to Prometheus service
   - Pre-configured datasources
   - Provisioned dashboards

---

## 📞 References & Resources

### Official Documentation

- **Prometheus**: https://prometheus.io/docs/
- **PromQL**: https://prometheus.io/docs/prometheus/latest/querying/basics/
- **Kubernetes Monitoring**: https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/

### Best Practices

- **Prometheus Best Practices**: https://prometheus.io/docs/practices/naming/
- **Metric Naming Conventions**: https://prometheus.io/docs/practices/naming/
- **Recording Rules**: https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/

### Tutorials

- **Prometheus + Kubernetes**: https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config
- **FastAPI + Prometheus**: https://github.com/prometheus/client_python

---

## ✅ Summary

Phase 7 represents a critical milestone in the project's evolution from basic deployment to **production-ready observability**. By implementing Prometheus monitoring:

1. **Technical Achievement**:
   - Complete monitoring stack foundation
   - Metrics collection from FastAPI
   - Persistent time-series storage
   - Self-healing monitoring system

2. **Educational Value**:
   - Deep dive into observability concepts
   - Hands-on with Prometheus
   - Kubernetes ConfigMaps and PVCs
   - Production monitoring patterns

3. **Project Progression**:
   - Builds on Phases 5-6 (core deployments)
   - Enables Phase 8 (Grafana visualization)
   - Prepares for Phase 9 (Ingress/external access)

4. **Best Practices**:
   - Follows established documentation patterns
   - Maintains Helm templating consistency
   - Implements security considerations
   - Includes comprehensive testing

**Phase 7 is the logical and necessary next step** in transforming this FastAPI application into a fully observable, production-ready microservice.

---

**Document Version**: 1.0  
**Created**: January 31, 2026  
**Status**: Ready for Implementation

---

*Bespoke Labs Assignment - Phase 7 Plan*
