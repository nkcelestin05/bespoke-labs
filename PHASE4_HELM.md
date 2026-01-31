# Phase 4: Creating the Helm Chart Structure

## 🎯 Overview

In this phase, we create the foundational structure for our Helm chart. This is the "blueprint" that will allow us to deploy our entire application stack (FastAPI, PostgreSQL, Prometheus, Grafana) to Kubernetes with a single command.

## 📚 What is Helm?

### The Package Manager for Kubernetes

Think of Helm like `apt` for Ubuntu or `npm` for Node.js, but for Kubernetes applications:

- **Without Helm**: You'd need to manually create and manage 20+ YAML files for deployments, services, configmaps, secrets, etc.
- **With Helm**: One command deploys everything with sensible defaults, and you can customize via simple configuration.

### Key Concepts

```
Helm Chart (Package)
├── Chart.yaml         ← Metadata (name, version, description)
├── values.yaml        ← Configuration (all customizable values)
└── templates/         ← Kubernetes YAML templates with placeholders
    ├── deployment.yaml
    ├── service.yaml
    └── ...
```

**Analogy**: 
- `Chart.yaml` = Package information (like `package.json`)
- `values.yaml` = User preferences (like `.env` file)
- `templates/` = Reusable blueprints with variables

## 📋 Chart.yaml - The Chart Metadata

### What We Created

```yaml
apiVersion: v2
name: wiki-chart
description: Helm chart for Wikipedia-like API service with PostgreSQL, Prometheus, and Grafana
type: application
version: 0.1.0
appVersion: "1.0"
```

### Field Explanations

| Field | Purpose | Example |
|-------|---------|---------|
| `apiVersion` | Helm chart API version (v2 is latest) | `v2` |
| `name` | Chart name (must match directory name) | `wiki-chart` |
| `description` | Human-readable description | See above |
| `type` | `application` (app) or `library` (helper) | `application` |
| `version` | Chart version (for chart changes) | `0.1.0` → `0.2.0` |
| `appVersion` | Application version (what you deploy) | `1.0` → `1.1` |

**Important Distinction**:
- **Chart version**: Changes when you modify Helm templates/values
- **App version**: Changes when your application code changes

## 🎨 values.yaml - The Configuration Heart

### Structure Overview

Our `values.yaml` is organized into 5 main sections:

```yaml
fastapi:        # Your FastAPI application
postgresql:     # Database
prometheus:     # Metrics collection
grafana:        # Metrics visualization
ingress:        # External access routing
```

### How Values Work

**values.yaml defines defaults**:
```yaml
fastapi:
  replicaCount: 2
  image:
    tag: "latest"
```

**Templates reference these values**:
```yaml
# In templates/fastapi-deployment.yaml
replicas: {{ .Values.fastapi.replicaCount }}  # Becomes: replicas: 2
image: {{ .Values.fastapi.image.tag }}        # Becomes: image: latest
```

**Users can override at install time**:
```bash
helm install wiki ./wiki-chart --set fastapi.replicaCount=5
# Now deploys 5 replicas instead of 2!
```

### Deep Dive: FastAPI Configuration

```yaml
fastapi:
  image:
    repository: wiki-service    # Local image name
    tag: "latest"               # Image tag
    pullPolicy: IfNotPresent    # Don't pull if exists locally
  
  replicaCount: 2               # High availability (2 pods)
  
  service:
    type: ClusterIP             # Internal-only (Ingress handles external)
    port: 8000                  # Port for accessing the service
  
  resources:
    requests:                   # Guaranteed resources
      cpu: "100m"               # 0.1 CPU cores
      memory: "128Mi"           # 128 MB RAM
    limits:                     # Maximum allowed
      cpu: "500m"               # 0.5 CPU cores
      memory: "512Mi"           # 512 MB RAM
  
  env:                          # Environment variables
    DB_HOST: "postgres-service" # References PostgreSQL service
    DB_PORT: "5432"
    DB_NAME: "wikidb"
```

**Why This Matters**:
- **Resource requests**: Kubernetes guarantees you get this much
- **Resource limits**: Prevents one service from consuming all resources
- **Health checks**: Kubernetes restarts unhealthy pods automatically

### Deep Dive: PostgreSQL Configuration

```yaml
postgresql:
  image:
    repository: postgres
    tag: "16-alpine"            # Alpine = smaller image (~80MB vs 300MB)
  
  database:
    name: wikidb
    user: postgres
    password: postgres          # ⚠️ CHANGE IN PRODUCTION!
  
  persistence:
    enabled: true               # Data survives pod restarts
    size: 1Gi                   # 1 GB storage
    accessMode: ReadWriteOnce   # One pod can write at a time
```

**Persistence Deep Dive**:
- Without persistence: Database data is lost when pod restarts
- With persistence: Kubernetes creates a PersistentVolume (actual disk storage)
- `ReadWriteOnce`: Only one node can mount (fine for single-instance DB)

### Deep Dive: Prometheus Configuration

```yaml
prometheus:
  scrapeInterval: 15s           # How often to collect metrics
  
  scrapeConfigs:
    - job_name: 'fastapi'
      static_configs:
        - targets: ['fastapi-service:8000']
      metrics_path: '/metrics'  # Your FastAPI endpoint
```

**How It Works**:
1. Prometheus calls `http://fastapi-service:8000/metrics` every 15s
2. FastAPI returns metrics (request count, latency, etc.)
3. Prometheus stores time-series data
4. Grafana queries Prometheus to create dashboards

### Deep Dive: Grafana Configuration

```yaml
grafana:
  adminUser: admin
  adminPassword: admin          # ⚠️ CHANGE IN PRODUCTION!
  
  datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-service:9090
      isDefault: true           # Auto-connects to Prometheus
  
  dashboards:
    enabled: true
    path: /etc/grafana/provisioning/dashboards
```

**Auto-Configuration Magic**:
- Grafana automatically connects to Prometheus (no manual setup!)
- Dashboards can be pre-loaded from ConfigMaps
- Users can create custom dashboards in the UI

### Deep Dive: Ingress Configuration

```yaml
ingress:
  enabled: true
  className: nginx              # Uses nginx ingress controller
  
  hosts:
    - host: wiki-api.local      # Domain name
      paths:
        - path: /               # Routes to FastAPI
          service:
            name: fastapi-service
            port: 8000
        
        - path: /grafana        # Routes to Grafana
          service:
            name: grafana-service
            port: 3000
```

**Routing Logic**:
```
http://wiki-api.local/          → FastAPI (port 8000)
http://wiki-api.local/users     → FastAPI (port 8000)
http://wiki-api.local/grafana   → Grafana (port 3000)
http://wiki-api.local/prometheus → Prometheus (port 9090)
```

**Local Development Setup**:
Add to `/etc/hosts`:
```
127.0.0.1  wiki-api.local
```

## 🔧 How Values Are Referenced in Templates

### Syntax Examples

```yaml
# Accessing top-level values
{{ .Values.fastapi.replicaCount }}

# Accessing nested values
{{ .Values.fastapi.image.repository }}:{{ .Values.fastapi.image.tag }}

# With default fallback
{{ .Values.fastapi.service.port | default 8000 }}

# Conditional rendering
{{- if .Values.ingress.enabled }}
# ... ingress configuration
{{- end }}

# Looping through lists
{{- range .Values.prometheus.scrapeConfigs }}
- job_name: {{ .job_name }}
{{- end }}
```

### Built-in Values

Helm provides additional values automatically:

```yaml
{{ .Release.Name }}       # Name of the Helm release (e.g., "wiki-release")
{{ .Release.Namespace }}  # Kubernetes namespace
{{ .Chart.Name }}         # Chart name from Chart.yaml
{{ .Chart.Version }}      # Chart version from Chart.yaml
```

## 🚀 Benefits of Using Helm

### 1. **Simplified Deployment**

**Without Helm**:
```bash
kubectl apply -f fastapi-deployment.yaml
kubectl apply -f fastapi-service.yaml
kubectl apply -f postgres-statefulset.yaml
kubectl apply -f postgres-service.yaml
kubectl apply -f postgres-pvc.yaml
kubectl apply -f prometheus-deployment.yaml
# ... 15 more files
```

**With Helm**:
```bash
helm install wiki ./wiki-chart
# Everything deployed! ✅
```

### 2. **Easy Upgrades**

```bash
# Change values.yaml or upgrade app version
helm upgrade wiki ./wiki-chart

# Rollback if something breaks
helm rollback wiki
```

### 3. **Environment Management**

```bash
# Development
helm install wiki ./wiki-chart -f values-dev.yaml

# Staging
helm install wiki ./wiki-chart -f values-staging.yaml

# Production
helm install wiki ./wiki-chart -f values-prod.yaml
```

### 4. **Reusability**

- Share your chart with others
- Publish to Helm repositories
- Version control your deployment configuration

### 5. **Declarative Configuration**

Everything is code! You can:
- Track changes in Git
- Review changes via pull requests
- Automate deployments in CI/CD

## 📁 Current Directory Structure

```
wiki-chart/
├── Chart.yaml           ✅ Created (chart metadata)
├── values.yaml          ✅ Created (default configuration)
├── templates/           ✅ Exists (will create templates in Phases 5-9)
│   └── (empty for now)
└── dashboards/          ✅ Exists (for Grafana dashboards)
    └── (empty for now)
```

## 🎓 Key Takeaways

1. **Helm = Package Manager**: Bundles Kubernetes resources into manageable charts
2. **Chart.yaml = Metadata**: Identifies your chart (name, version, description)
3. **values.yaml = Configuration**: All customizable settings in one place
4. **Templates Reference Values**: Using `{{ .Values.key }}` syntax
5. **Separation of Concerns**: Configuration (values) vs. Structure (templates)

## 🔜 Next Steps: Phases 5-9

Now that we have the foundation, we'll create Kubernetes templates for each component:

### **Phase 5: PostgreSQL Resources** (StatefulSet + Service)
- StatefulSet for database (handles persistence)
- Service for database networking
- Secret for credentials

### **Phase 6: FastAPI Resources** (Deployment + Service)
- Deployment for application pods
- Service for load balancing
- ConfigMap for environment variables

### **Phase 7: Prometheus Resources** (Deployment + ConfigMap)
- Deployment for metrics collection
- ConfigMap for scrape configuration
- Service for Grafana to query

### **Phase 8: Grafana Resources** (Deployment + ConfigMap)
- Deployment for visualization
- ConfigMap for datasource + dashboards
- Service for web UI access

### **Phase 9: Ingress Resource** (External Access)
- Ingress for routing external traffic
- Path-based routing to services

## 💡 Pro Tips

### Security Best Practices

1. **Never commit secrets**: Use Kubernetes Secrets or external secret managers
2. **Change default passwords**: Update `values.yaml` before production
3. **Use non-root containers**: Our Dockerfile already does this ✅

### Performance Optimization

1. **Set resource limits**: Prevents resource starvation
2. **Use health checks**: Kubernetes auto-restarts failed pods
3. **Enable persistence**: Data survives pod restarts

### Development Workflow

1. **Test locally**: Use `helm template` to see generated YAML without deploying
   ```bash
   helm template wiki ./wiki-chart > output.yaml
   ```

2. **Validate syntax**: Check for errors before deploying
   ```bash
   helm lint ./wiki-chart
   ```

3. **Dry run**: Simulate deployment
   ```bash
   helm install wiki ./wiki-chart --dry-run --debug
   ```

## 📚 Additional Resources

- [Helm Official Docs](https://helm.sh/docs/)
- [Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [values.yaml Schema](https://helm.sh/docs/topics/charts/#values-files)
- [Template Functions](https://helm.sh/docs/chart_template_guide/function_list/)

## ✅ Phase 4 Complete!

You now have:
- ✅ Chart metadata (`Chart.yaml`)
- ✅ Comprehensive configuration (`values.yaml`)
- ✅ Directory structure for templates and dashboards
- ✅ Understanding of Helm concepts and benefits

**Ready to move to Phase 5!** 🚀
