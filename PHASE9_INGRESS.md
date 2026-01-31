# Phase 9: Ingress Configuration for External Access

## Overview

In Phase 9, we deploy Kubernetes Ingress to expose our entire application stack to external users. This phase transforms our internal-only services into a publicly accessible application with proper routing and production-ready features.

**What we're deploying:**
- Kubernetes Ingress resource with routing rules
- Path-based routing for all three services (FastAPI, Grafana, Prometheus)
- nginx Ingress Controller configuration
- SSL/TLS support (configurable)
- Production-ready annotations

**Why external access matters:**
- Internal ClusterIP services are only accessible within the Kubernetes cluster
- Users and monitoring tools need external access via HTTP/HTTPS
- Single unified entry point is easier to manage than multiple NodePorts
- Ingress provides Layer 7 routing, SSL termination, and advanced features
- Professional production deployment pattern

**The Access Journey:**
- **Phase 5**: PostgreSQL (internal database, no external access needed)
- **Phase 6**: FastAPI service (ClusterIP, internal only)
- **Phase 7**: Prometheus service (ClusterIP, internal only)
- **Phase 8**: Grafana service (ClusterIP, internal only)
- **Phase 9**: Ingress exposes all services externally with unified access ← We are here
- **Phase 10**: Preview - CI/CD, advanced monitoring, or infrastructure automation

---

## Files Created

### 1. `ingress.yaml`
Defines routing rules to expose FastAPI, Grafana, and Prometheus externally via a single domain with path-based routing.

---

## What is Kubernetes Ingress?

### The External Access Problem

Imagine you're running a restaurant with three departments:
- **Kitchen** (FastAPI): Prepares orders, internal operations
- **Dashboard** (Grafana): Shows performance metrics to management
- **Quality Monitor** (Prometheus): Tracks quality and timing metrics

Each department operates independently with internal phone extensions:
- Kitchen: Extension 8000
- Dashboard: Extension 3000  
- Quality Monitor: Extension 9090

**Problem**: Customers and managers outside the building can't reach these extensions directly. How do they access your services?

**Bad Solutions:**
1. **Expose each extension externally** (NodePort approach)
   - Kitchen accessible at: restaurant.com:30800
   - Dashboard accessible at: restaurant.com:30300
   - Quality Monitor accessible at: restaurant.com:30900
   - ❌ Ugly URLs with port numbers
   - ❌ Firewall needs multiple ports open
   - ❌ Hard to remember different ports
   - ❌ Not professional

2. **Public phone number for each** (LoadBalancer approach)
   - Kitchen: 555-0100
   - Dashboard: 555-0200
   - Quality Monitor: 555-0300
   - ❌ Expensive (3 load balancers)
   - ❌ Wasteful (each service gets dedicated IP)
   - ❌ Harder to manage multiple IPs

**Ingress Solution** (Receptionist/API Gateway):
- Single entry point: restaurant.com (or 555-0100)
- Smart receptionist routes based on request:
  - "I want to order food" → Kitchen (restaurant.com/)
  - "I want to see dashboard" → Dashboard (restaurant.com/grafana)
  - "I want quality reports" → Quality Monitor (restaurant.com/prometheus)
- ✅ Clean URLs, no port numbers
- ✅ Single IP address
- ✅ SSL/HTTPS in one place
- ✅ Professional setup

### Ingress Explained

**Kubernetes Ingress** is an API object that manages external HTTP/HTTPS access to services in a cluster. It provides:

1. **Layer 7 Load Balancing**: Intelligent routing based on HTTP headers, paths, and hostnames
2. **SSL/TLS Termination**: Handles HTTPS encryption/decryption
3. **Name-based Virtual Hosting**: Multiple domains on single IP
4. **Path-based Routing**: Different URL paths to different services
5. **Centralized Configuration**: Single place to manage external access

### Key Concepts

#### 1. Ingress vs Ingress Controller

This is a common point of confusion!

**Ingress (Resource)**:
- A Kubernetes resource (YAML file)
- Defines *what* you want: routing rules, hosts, paths
- Just a configuration/specification
- Does nothing by itself

**Ingress Controller**:
- The actual software that implements the routing
- Reads Ingress resources and configures itself
- Handles the actual traffic
- Must be installed separately

**Analogy:**
- **Ingress Resource** = Restaurant menu (describes what's available)
- **Ingress Controller** = Kitchen that prepares the food

**Popular Ingress Controllers:**
- **nginx** ← We use this (most common, feature-rich)
- **Traefik** (automatic, modern, easy)
- **HAProxy** (high performance)
- **Contour** (Envoy-based)
- **AWS ALB** (cloud-native for AWS)
- **GCE** (cloud-native for Google Cloud)

#### 2. Path-based Routing vs Host-based Routing

**Path-based Routing** (What we use):
```
Single domain, different paths:
http://wiki-api.local/          → FastAPI
http://wiki-api.local/grafana   → Grafana
http://wiki-api.local/prometheus → Prometheus
```

✅ **Advantages:**
- Simple DNS (single domain)
- Easy for development
- Single certificate for HTTPS
- Clear service organization

❌ **Disadvantages:**
- Path prefix must be handled (rewriting)
- Potential path conflicts
- URLs less clean

**Host-based Routing** (Alternative):
```
Different domains:
http://api.wiki.com       → FastAPI
http://grafana.wiki.com   → Grafana
http://prometheus.wiki.com → Prometheus
```

✅ **Advantages:**
- Clean URLs (no path prefix)
- Clear service separation
- No path conflicts
- More professional

❌ **Disadvantages:**
- Multiple DNS entries
- More complex setup
- Potentially more certificates
- Harder for local development

**When to use which:**
- **Development/Local**: Path-based (easier)
- **Production**: Either works, host-based is slightly cleaner
- **Microservices**: Host-based scales better
- **Simple apps**: Path-based is sufficient

#### 3. How Ingress Works

```
┌──────────────────────────────────────────────────────────────┐
│                     External User                             │
│                         Browser                               │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            │ 1. HTTP Request
                            │ GET http://wiki-api.local/grafana
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                         DNS Resolution                         │
│            wiki-api.local → 192.168.49.2 (Minikube IP)        │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            │ 2. Request to Ingress Controller
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                  Ingress Controller (nginx)                   │
│                      Running in Cluster                        │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ 1. Receives request on port 80/443                   │    │
│  │ 2. Reads Ingress resources                           │    │
│  │ 3. Matches host: wiki-api.local                      │    │
│  │ 4. Matches path: /grafana                            │    │
│  │ 5. Strips /grafana prefix (rewrite-target)           │    │
│  │ 6. Forwards to: grafana-service:3000                 │    │
│  └──────────────────────────────────────────────────────┘    │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            │ 3. Forward to Service
                            │ (rewritten path: /)
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│               Kubernetes Service (ClusterIP)                  │
│                    grafana-service:3000                       │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ 1. Receives request from Ingress Controller          │    │
│  │ 2. Load balances across healthy pods                 │    │
│  │ 3. Forwards to pod on port 3000                      │    │
│  └──────────────────────────────────────────────────────┘    │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            │ 4. Forward to Pod
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                      Grafana Pod                              │
│                  Container Port 3000                          │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ 1. Receives HTTP request                             │    │
│  │ 2. Processes request (GET /)                         │    │
│  │ 3. Returns Grafana UI HTML                           │    │
│  └──────────────────────────────────────────────────────┘    │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            │ 5. Response flows back
                            │
                            ▼
                    User sees Grafana UI
```

**Request Flow Detailed:**

1. **User makes request**: `http://wiki-api.local/grafana`
2. **DNS resolution**: wiki-api.local → 192.168.49.2 (Ingress Controller IP)
3. **Ingress Controller receives**: nginx pod on port 80
4. **Match host**: wiki-api.local (matches Ingress rule)
5. **Match path**: /grafana (matches path rule)
6. **Apply annotations**: 
   - Rewrite: /grafana/dashboard → /dashboard
   - Headers: X-Real-IP, X-Forwarded-For
7. **Forward to service**: grafana-service:3000
8. **Service load balances**: Picks healthy pod
9. **Pod responds**: Grafana container processes request
10. **Response flows back**: Through same path to user

#### 4. Path Rewriting

**The Problem:**

Grafana expects to be hosted at root path `/`:
- Grafana dashboard: `/dashboard`
- Grafana API: `/api/datasources`
- Grafana assets: `/public/css/grafana.css`

But we're hosting Grafana at `/grafana`:
- User requests: `/grafana/dashboard`
- Grafana receives: `/grafana/dashboard`
- Grafana looks for: `/dashboard` (doesn't exist!)
- Result: 404 Not Found ❌

**The Solution: Path Rewriting**

```yaml
annotations:
  nginx.ingress.kubernetes.io/rewrite-target: /$2
```

With path pattern: `/grafana(/|$)(.*)`

**How it works:**

```
┌────────────────────────────────────────────────────────────┐
│ User Request: /grafana/dashboard                           │
└─────────────────────┬──────────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────────┐
│ Regex Pattern: /grafana(/|$)(.*)                           │
│ ├─ /grafana          : Match literal prefix                │
│ ├─ (/|$)             : Match slash OR end of string        │
│ └─ (.*)              : Capture rest of path ($2)           │
└─────────────────────┬──────────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────────┐
│ Captured: $2 = "/dashboard"                                │
└─────────────────────┬──────────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────────┐
│ Rewrite: /$2 = "/dashboard"                                │
└─────────────────────┬──────────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────────┐
│ Forwarded to Grafana: /dashboard ✅                         │
└────────────────────────────────────────────────────────────┘
```

**Examples:**

| User Request | Pattern Match | $2 Captured | Rewritten | Sent to Backend |
|--------------|---------------|-------------|-----------|-----------------|
| `/grafana` | ✅ `/grafana($)` | `` (empty) | `/` | `/` |
| `/grafana/` | ✅ `/grafana(/)(.*)` | `/` | `/` | `/` |
| `/grafana/dashboard` | ✅ `/grafana(/)(.*)` | `/dashboard` | `/dashboard` | `/dashboard` |
| `/grafana/api/health` | ✅ `/grafana(/)(.*)` | `/api/health` | `/api/health` | `/api/health` |
| `/prometheus/graph` | ✅ `/prometheus(/)(.*)` | `/graph` | `/graph` | `/graph` |

**Why we need `(/|$)`:**

Without it, regex `/grafana(.*)` would match:
- `/grafana-test` ❌ (Wrong! Not our service)
- `/grafanabackup` ❌ (Wrong! Not our service)

With `(/|$)`, it only matches:
- `/grafana` ✅ (Exact match)
- `/grafana/` ✅ (With trailing slash)
- `/grafana/anything` ✅ (Subpaths)

#### 5. TLS/SSL Termination

**What is SSL/TLS?**

SSL/TLS encrypts HTTP traffic (HTTP → HTTPS) to protect:
- User credentials (passwords)
- Session cookies
- Sensitive data
- Against man-in-the-middle attacks

**Where to handle TLS:**

```
Option 1: TLS at each service (DON'T DO THIS)
┌─────────────┐ HTTPS ┌─────────┐ HTTPS ┌──────────┐
│   Client    ├───────►│ Service1├───────►│ Database │
└─────────────┘        └─────────┘        └──────────┘
                       ┌─────────┐ HTTPS
                       │ Service2├───────►
                       └─────────┘
❌ Multiple certificates
❌ Complex management
❌ Performance overhead

Option 2: TLS at Ingress (BEST PRACTICE)
┌─────────────┐ HTTPS ┌─────────┐ HTTP ┌─────────┐
│   Client    ├───────►│ Ingress ├──────►│ Service │
└─────────────┘        └────┬────┘       └─────────┘
                            │ HTTP
                            └──────────►┌─────────┐
                                        │ Service2│
                                        └─────────┘
✅ Single certificate
✅ Centralized management
✅ Internal traffic can be plain HTTP
```

**TLS Termination at Ingress:**

```yaml
tls:
  - secretName: wiki-api-tls
    hosts:
      - wiki-api.example.com
```

**How it works:**

1. **Client initiates HTTPS**: `https://wiki-api.example.com/grafana`
2. **TLS handshake**: Client and Ingress establish encrypted connection
3. **Certificate validation**: Client verifies Ingress certificate
4. **Encrypted request**: Client sends encrypted HTTP request
5. **Ingress decrypts**: Ingress decrypts using private key
6. **Plain HTTP forwarding**: Ingress forwards plain HTTP to backend
7. **Backend responds**: Service returns plain HTTP response
8. **Ingress encrypts**: Ingress encrypts response
9. **Client receives**: Encrypted HTTPS response

**Benefits:**
- ✅ Backend services don't need TLS configuration
- ✅ Single place to manage certificates
- ✅ Easier to update/rotate certificates
- ✅ Better performance (TLS overhead only at edge)
- ✅ Internal traffic can be plain HTTP (faster)

**Certificate Sources:**

1. **Self-signed** (Development):
   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout tls.key -out tls.crt \
     -subj "/CN=wiki-api.local"
   kubectl create secret tls wiki-api-tls --cert=tls.crt --key=tls.key
   ```

2. **Let's Encrypt** (Production, Free):
   - Use cert-manager
   - Automatic certificate issuance
   - Auto-renewal before expiry

3. **Commercial CA** (Production, Paid):
   - Buy certificate from CA
   - Upload to Kubernetes Secret
   - Manual renewal

---

## Our Ingress Configuration

### Routing Strategy

We use **path-based routing** with a single domain:

```
Domain: wiki-api.local

Paths:
├─ /                    → fastapi-service:8000 (API)
├─ /grafana(/|$)(.*)    → grafana-service:3000 (Visualization)
└─ /prometheus(/|$)(.*) → prometheus-service:9090 (Metrics)
```

**Why this approach:**
1. **Simple DNS**: Single entry in /etc/hosts or DNS
2. **Easy development**: One domain to remember
3. **Single certificate**: One cert for all services
4. **Clear organization**: Path indicates service

### Annotations Explained

Our Ingress uses several nginx-specific annotations:

#### 1. Path Rewriting

```yaml
nginx.ingress.kubernetes.io/rewrite-target: /$2
```

- Strips path prefix before forwarding
- `/grafana/dashboard` → `/dashboard`
- Required because Grafana expects root path

#### 2. Configuration Snippet

```yaml
nginx.ingress.kubernetes.io/configuration-snippet: |
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_read_timeout 300s;
```

**What each does:**

- **`Host $host`**: Preserve original hostname
  - Important for Grafana (validates hostname)
  - Backend sees: wiki-api.local (not internal service name)

- **`X-Real-IP $remote_addr`**: Real client IP address
  - Backend logs show actual client IP
  - Not the Ingress Controller IP
  - Important for rate limiting, geolocation

- **`X-Forwarded-For $proxy_add_x_forwarded_for`**: Chain of proxy IPs
  - Shows full proxy chain
  - Format: `client-ip, proxy1-ip, proxy2-ip`
  - Standard header for proxied requests

- **`X-Forwarded-Proto $scheme`**: Original protocol (http/https)
  - Backend knows if client used HTTPS
  - Helps with redirect logic
  - Important for security policies

- **`proxy_read_timeout 300s`**: Backend response timeout
  - Wait up to 5 minutes for response
  - Prevents timeout on long queries
  - Prometheus/Grafana can have slow queries

#### 3. Additional Production Annotations (Commented)

```yaml
# Force HTTPS redirect
nginx.ingress.kubernetes.io/ssl-redirect: "true"

# Rate limiting (requests per second)
nginx.ingress.kubernetes.io/rate-limit: "100"

# Basic authentication
nginx.ingress.kubernetes.io/auth-type: basic
nginx.ingress.kubernetes.io/auth-secret: basic-auth

# Let's Encrypt certificate
cert-manager.io/cluster-issuer: letsencrypt-prod
```

### Service Name Resolution

The Ingress must reference actual Kubernetes service names:

```yaml
# User-friendly name in values.yaml
service:
  name: grafana-service

# Actual service name in cluster (with release name)
# wiki-chart-grafana
```

Our template handles this with Helm helpers:

```yaml
{{- if eq .service.name "grafana-service" }}
name: {{ include "wiki-chart.fullname" $ }}-grafana
{{- else if eq .service.name "prometheus-service" }}
name: {{ include "wiki-chart.fullname" $ }}-prometheus
{{- else if eq .service.name "fastapi-service" }}
name: {{ include "wiki-chart.fullname" $ }}-fastapi
{{- end }}
```

---

## Step-by-Step Implementation

### Step 1: Install nginx Ingress Controller

The Ingress resource alone does nothing. We need an Ingress Controller.

#### For Minikube:

```bash
# Enable ingress addon
minikube addons enable ingress

# Verify installation
kubectl get pods -n ingress-nginx
```

Expected output:
```
NAME                                        READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-5d88495688-xxxxx   1/1     Running   0          1m
```

#### For Cloud Kubernetes (GKE, EKS, AKS):

```bash
# Install nginx ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

# Wait for LoadBalancer IP
kubectl get svc -n ingress-nginx
```

Expected output:
```
NAME                                 TYPE           EXTERNAL-IP    PORT(S)
ingress-nginx-controller             LoadBalancer   34.123.45.67   80:32080/TCP,443:32443/TCP
```

#### For Local Kubernetes (Docker Desktop, kind):

```bash
# Install nginx ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

# Port forward to access
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

### Step 2: Configure DNS

For external access, we need a domain name to resolve to the Ingress Controller IP.

#### Development (Minikube/Local):

```bash
# Get Minikube IP
minikube ip
# Output: 192.168.49.2

# Add to /etc/hosts (macOS/Linux)
sudo nano /etc/hosts

# Add this line:
192.168.49.2 wiki-api.local

# Save and exit (Ctrl+X, Y, Enter)

# Test DNS resolution
ping wiki-api.local
# Should respond from 192.168.49.2
```

#### Development (Docker Desktop):

```bash
# Add to /etc/hosts
sudo nano /etc/hosts

# Add this line:
127.0.0.1 wiki-api.local
```

#### Production (Real Domain):

```bash
# Get Ingress Controller LoadBalancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
# Note the EXTERNAL-IP

# In your DNS provider (Cloudflare, Route53, etc.):
# Add A record:
# Name: wiki-api (or @for root)
# Type: A
# Value: <EXTERNAL-IP>
# TTL: 300
```

### Step 3: Deploy the Application

```bash
# Ensure you're in the project directory
cd /path/to/bespoke-labs

# Deploy with Helm
helm install wiki-chart ./wiki-chart

# Or if already installed, upgrade:
helm upgrade wiki-chart ./wiki-chart

# Watch for pods to start
kubectl get pods -w
```

Expected output:
```
NAME                                 READY   STATUS    RESTARTS   AGE
wiki-chart-fastapi-xxxxxx-xxxxx      1/1     Running   0          2m
wiki-chart-fastapi-xxxxxx-xxxxx      1/1     Running   0          2m
wiki-chart-grafana-xxxxxx-xxxxx      1/1     Running   0          2m
wiki-chart-postgres-xxxxxx-xxxxx     1/1     Running   0          2m
wiki-chart-prometheus-xxxxxx-xxxxx   1/1     Running   0          2m
```

### Step 4: Verify Ingress

```bash
# Check Ingress resource
kubectl get ingress

# Expected output:
# NAME                    CLASS   HOSTS            ADDRESS        PORTS   AGE
# wiki-chart-ingress      nginx   wiki-api.local   192.168.49.2   80      5m

# Describe for more details
kubectl describe ingress wiki-chart-ingress
```

Look for:
- **Rules**: Should show all three path rules
- **Backend**: Should reference service:port correctly
- **Events**: Should show no errors

### Step 5: Test Access

#### Test FastAPI:

```bash
# Health check
curl http://wiki-api.local/health

# Expected: {"status": "healthy"}

# API documentation
curl http://wiki-api.local/docs
# Or open in browser: http://wiki-api.local/docs

# Create an article
curl -X POST http://wiki-api.local/articles \
  -H "Content-Type: application/json" \
  -d '{"title": "Ingress Test", "content": "Testing external access!"}'

# Get metrics
curl http://wiki-api.local/metrics
```

#### Test Grafana:

```bash
# Open in browser
open http://wiki-api.local/grafana

# Or curl
curl http://wiki-api.local/grafana
# Should return Grafana HTML

# Login:
# Username: admin
# Password: admin
```

**After login:**
1. Change default password (Grafana prompts)
2. Go to Configuration → Data Sources
3. Verify Prometheus datasource is configured
4. Create dashboard (see Phase 8 documentation)

#### Test Prometheus:

```bash
# Open in browser
open http://wiki-api.local/prometheus

# Or curl
curl http://wiki-api.local/prometheus
# Should return Prometheus HTML

# Check targets
open http://wiki-api.local/prometheus/targets
# Should show fastapi and prometheus targets as UP

# Query metrics
curl 'http://wiki-api.local/prometheus/api/v1/query?query=up'
```

### Step 6: Verify Path Rewriting

Test that path rewriting works correctly:

```bash
# Grafana - Should work without /grafana prefix internally
curl -I http://wiki-api.local/grafana/api/health

# Should return:
# HTTP/1.1 200 OK

# Prometheus - Should work without /prometheus prefix internally
curl -I http://wiki-api.local/prometheus/api/v1/targets

# Should return:
# HTTP/1.1 200 OK

# Without rewriting, these would return 404
```

---

## Testing and Verification Procedures

### 1. Basic Connectivity Test

```bash
#!/bin/bash
# test-ingress-basic.sh

echo "Testing Ingress Basic Connectivity..."

# Test FastAPI
echo -n "FastAPI health: "
if curl -s http://wiki-api.local/health | grep -q "healthy"; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi

# Test Grafana
echo -n "Grafana access: "
if curl -s http://wiki-api.local/grafana | grep -q "Grafana"; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi

# Test Prometheus
echo -n "Prometheus access: "
if curl -s http://wiki-api.local/prometheus | grep -q "Prometheus"; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi
```

### 2. Path Rewriting Test

```bash
#!/bin/bash
# test-path-rewriting.sh

echo "Testing Path Rewriting..."

# Grafana API (should work with /grafana prefix)
echo -n "Grafana API (/grafana/api/health): "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://wiki-api.local/grafana/api/health)
if [ "$STATUS" = "200" ]; then
  echo "✅ PASS (HTTP $STATUS)"
else
  echo "❌ FAIL (HTTP $STATUS)"
fi

# Prometheus API (should work with /prometheus prefix)
echo -n "Prometheus API (/prometheus/api/v1/query): "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://wiki-api.local/prometheus/api/v1/query?query=up")
if [ "$STATUS" = "200" ]; then
  echo "✅ PASS (HTTP $STATUS)"
else
  echo "❌ FAIL (HTTP $STATUS)"
fi

# FastAPI (no prefix needed)
echo -n "FastAPI (/health): "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://wiki-api.local/health)
if [ "$STATUS" = "200" ]; then
  echo "✅ PASS (HTTP $STATUS)"
else
  echo "❌ FAIL (HTTP $STATUS)"
fi
```

### 3. Performance Test

```bash
#!/bin/bash
# test-ingress-performance.sh

echo "Testing Ingress Performance..."

# Test response time
echo "Response times:"

for service in "/" "/grafana" "/prometheus"; do
  echo -n "  $service: "
  TIME=$(curl -s -o /dev/null -w "%{time_total}" http://wiki-api.local$service)
  echo "${TIME}s"
done

# Load test (requires 'ab' - Apache Bench)
echo ""
echo "Load test (100 requests, 10 concurrent):"
ab -n 100 -c 10 http://wiki-api.local/health
```

### 4. Headers Verification Test

```bash
#!/bin/bash
# test-headers.sh

echo "Testing Header Propagation..."

# Check if X-Forwarded headers are set
curl -v http://wiki-api.local/health 2>&1 | grep -i "x-forwarded"

# Expected headers in backend logs:
# X-Real-IP: <your-ip>
# X-Forwarded-For: <your-ip>
# X-Forwarded-Proto: http
# Host: wiki-api.local
```

### 5. End-to-End Integration Test

```bash
#!/bin/bash
# test-e2e.sh

echo "End-to-End Integration Test..."

# 1. Create article via FastAPI
echo "1. Creating article via Ingress..."
ARTICLE_ID=$(curl -s -X POST http://wiki-api.local/articles \
  -H "Content-Type: application/json" \
  -d '{"title": "E2E Test", "content": "Testing full stack"}' | jq -r '.id')

if [ ! -z "$ARTICLE_ID" ]; then
  echo "   ✅ Article created: ID=$ARTICLE_ID"
else
  echo "   ❌ Failed to create article"
  exit 1
fi

# 2. Verify article exists
echo "2. Verifying article via Ingress..."
TITLE=$(curl -s http://wiki-api.local/articles/$ARTICLE_ID | jq -r '.title')

if [ "$TITLE" = "E2E Test" ]; then
  echo "   ✅ Article retrieved successfully"
else
  echo "   ❌ Failed to retrieve article"
  exit 1
fi

# 3. Wait for metrics scraping
echo "3. Waiting for Prometheus scrape (15s)..."
sleep 15

# 4. Check Prometheus has metrics
echo "4. Verifying Prometheus metrics..."
METRIC=$(curl -s 'http://wiki-api.local/prometheus/api/v1/query?query=fastapi_http_requests_total' | jq -r '.data.result[0].value[1]')

if [ ! -z "$METRIC" ]; then
  echo "   ✅ Metrics available in Prometheus"
else
  echo "   ❌ No metrics in Prometheus"
  exit 1
fi

# 5. Verify Grafana can query Prometheus
echo "5. Testing Grafana datasource..."
curl -s -u admin:admin http://wiki-api.local/grafana/api/datasources | jq '.'

echo ""
echo "✅ All tests passed!"
```

---

## Troubleshooting Guide

### Common Issue #1: "Unable to connect" or Connection Timeout

**Symptoms:**
```bash
$ curl http://wiki-api.local
curl: (7) Failed to connect to wiki-api.local: Connection refused
```

**Possible Causes & Solutions:**

#### A. Ingress Controller Not Running

```bash
# Check ingress controller pods
kubectl get pods -n ingress-nginx

# If no pods or not running:
# For Minikube:
minikube addons enable ingress

# For others:
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
```

#### B. DNS Not Configured

```bash
# Test DNS resolution
ping wiki-api.local

# If "unknown host":
# Add to /etc/hosts
sudo nano /etc/hosts
# Add: <minikube-ip> wiki-api.local

# Get Minikube IP:
minikube ip
```

#### C. Ingress Has No ADDRESS

```bash
# Check Ingress
kubectl get ingress

# If ADDRESS column is empty:
# Wait a few minutes, or check ingress controller:
kubectl describe ingress wiki-chart-ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Common Issue #2: "404 Not Found"

**Symptoms:**
```bash
$ curl http://wiki-api.local
<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx</center>
</body>
</html>
```

**Possible Causes & Solutions:**

#### A. Service Names Don't Match

```bash
# Check actual service names
kubectl get services

# Should see:
# wiki-chart-fastapi
# wiki-chart-grafana
# wiki-chart-prometheus

# Verify Ingress references correct names
kubectl describe ingress wiki-chart-ingress

# Look for "Backend" - should match actual service names
```

#### B. Service Endpoints Not Ready

```bash
# Check service endpoints
kubectl get endpoints

# Should show pod IPs
# If empty, pods aren't ready:
kubectl get pods
kubectl describe pod <pod-name>
```

#### C. Wrong Path in Ingress

```bash
# Check Ingress rules
kubectl describe ingress wiki-chart-ingress

# Verify paths match what you're requesting
# Common mistake: Missing path in values.yaml
```

### Common Issue #3: "502 Bad Gateway"

**Symptoms:**
```bash
$ curl http://wiki-api.local
<html>
<head><title>502 Bad Gateway</title></head>
...
```

**Meaning**: Ingress can reach service, but service can't respond.

**Possible Causes & Solutions:**

#### A. Backend Pods Not Running

```bash
# Check pod status
kubectl get pods

# If not Running:
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Common issues:
# - Image pull error
# - Container crash
# - Failed health checks
```

#### B. Wrong Service Port

```bash
# Verify service ports
kubectl describe service wiki-chart-grafana

# Check TargetPort matches container port
# Ingress → Service Port → Target Port (Container)

# Should be:
# Service Port: 3000
# Target Port: 3000
# Container Port: 3000
```

#### C. Service Not Ready

```bash
# Check service readiness
kubectl get endpoints wiki-chart-grafana

# If no endpoints:
# Pods aren't passing readiness probe

# Check probe status:
kubectl describe pod <pod-name>
# Look for "Readiness probe failed"
```

### Common Issue #4: Grafana/Prometheus Shows "Page Not Found"

**Symptoms:**
- You can access http://wiki-api.local/grafana
- But Grafana shows "Not found" or blank page
- Or CSS/JS assets fail to load

**Cause**: Path rewriting is not working correctly.

**Solutions:**

#### A. Verify Rewrite Annotation

```bash
# Check Ingress annotations
kubectl describe ingress wiki-chart-ingress

# Should see:
# nginx.ingress.kubernetes.io/rewrite-target: /$2

# If missing, add to values.yaml:
ingress:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
```

#### B. Verify Path Pattern

```bash
# Paths must include capture group
kubectl get ingress wiki-chart-ingress -o yaml

# Should be:
# - path: /grafana(/|$)(.*)
#   NOT: /grafana
```

#### C. Check nginx Configuration

```bash
# View actual nginx config in controller
kubectl exec -n ingress-nginx <controller-pod-name> -- cat /etc/nginx/nginx.conf | grep -A 20 wiki-api.local

# Look for:
# rewrite ^/grafana(/|$)(.*) /$2 break;
```

#### D. Verify Backend Path Handling

```bash
# Test direct service access (port-forward)
kubectl port-forward svc/wiki-chart-grafana 3000:3000

# In another terminal:
curl http://localhost:3000/
# Should return Grafana HTML

# If direct access works but Ingress doesn't,
# it's a rewrite issue
```

### Common Issue #5: "Unable to verify grafana datasource"

**Symptoms:**
- Grafana loads fine
- But datasource shows "HTTP Error Bad Gateway"
- Or timeout errors

**Cause**: Grafana can't reach Prometheus through Ingress.

**Solutions:**

#### A. Internal Service Communication

Grafana should use **internal** service name, not Ingress URL:

```yaml
# ✅ Correct (in grafana-configmap-datasources.yaml)
datasources:
  - url: http://wiki-chart-prometheus:9090

# ❌ Wrong
datasources:
  - url: http://wiki-api.local/prometheus
```

Services within the cluster should talk directly to each other, not through Ingress.

#### B. Verify Prometheus Service

```bash
# Check Prometheus service exists
kubectl get service wiki-chart-prometheus

# Test from another pod
kubectl run -i --tty debug --image=curlimages/curl --rm -- sh
curl http://wiki-chart-prometheus:9090/api/v1/query?query=up
exit
```

### Common Issue #6: TLS/SSL Certificate Errors

**Symptoms:**
```bash
$ curl https://wiki-api.local
curl: (60) SSL certificate problem: self signed certificate
```

**Solutions:**

#### A. Development: Accept Self-Signed Certificates

```bash
# Curl: Use -k flag
curl -k https://wiki-api.local

# Browser: Click "Advanced" → "Proceed anyway"
```

#### B. Production: Use Proper Certificate

```bash
# Option 1: cert-manager (Automated)
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Create Let's Encrypt issuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Add annotation to Ingress
ingress:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod

# cert-manager will auto-create certificate
```

#### C. Verify Certificate

```bash
# Check certificate secret
kubectl describe secret wiki-api-tls

# Test with openssl
openssl s_client -connect wiki-api.local:443 -servername wiki-api.local

# Check expiry
kubectl get certificate wiki-api-tls
```

### Common Issue #7: High Latency or Slow Response

**Symptoms:**
- Requests take several seconds
- Timeouts on long queries

**Solutions:**

#### A. Increase Timeouts

```yaml
# In Ingress annotations:
nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
nginx.ingress.kubernetes.io/proxy-connect-timeout: "300"
```

#### B. Check Resource Limits

```bash
# Check if pods are CPU/memory throttled
kubectl top pods

# If high usage, increase limits in values.yaml:
resources:
  limits:
    cpu: "1000m"
    memory: "1Gi"
```

#### C. Enable Keep-Alive

```yaml
# In configuration-snippet:
nginx.ingress.kubernetes.io/configuration-snippet: |
  proxy_http_version 1.1;
  proxy_set_header Connection "";
```

### Common Issue #8: External IP Pending Forever

**Symptoms:**
```bash
$ kubectl get svc -n ingress-nginx
NAME                       TYPE           EXTERNAL-IP   PORT(S)
ingress-nginx-controller   LoadBalancer   <pending>     80:32080/TCP
```

**Solutions:**

#### A. Local Kubernetes (Minikube, kind, Docker Desktop)

LoadBalancer type doesn't work locally. Use alternatives:

```bash
# Minikube: Use minikube tunnel
minikube tunnel

# In another terminal:
kubectl get svc -n ingress-nginx
# EXTERNAL-IP should now show an IP

# Or use NodePort:
kubectl get svc -n ingress-nginx
# Note the NodePort (e.g., 32080)
# Access via: http://<node-ip>:32080
```

#### B. Cloud Kubernetes (Missing Cloud Provider Integration)

```bash
# Verify cloud controller manager is running
kubectl get pods -n kube-system | grep cloud-controller

# If missing, cluster wasn't set up with cloud provider

# Solution: Manually set up load balancer
# Or use NodePort and external load balancer
```

### Debugging Commands Cheatsheet

```bash
# Check all resources
kubectl get all

# Check Ingress
kubectl get ingress
kubectl describe ingress wiki-chart-ingress

# Check services
kubectl get svc
kubectl get endpoints

# Check pods
kubectl get pods
kubectl logs <pod-name>
kubectl describe pod <pod-name>

# Check Ingress Controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx <controller-pod>

# Test internal connectivity
kubectl run -i --tty debug --image=curlimages/curl --rm -- sh
curl http://wiki-chart-grafana:3000
exit

# View Ingress Controller config
kubectl exec -n ingress-nginx <controller-pod> -- cat /etc/nginx/nginx.conf

# Check events (recent issues)
kubectl get events --sort-by='.lastTimestamp'

# Port-forward for testing (bypass Ingress)
kubectl port-forward svc/wiki-chart-grafana 3000:3000
```

---

## Production Best Practices

### 1. TLS/SSL Certificates

**Development:**
```yaml
# No TLS
tls: []
```

**Production:**
```yaml
# With Let's Encrypt (free, automated)
ingress:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  tls:
    - secretName: wiki-api-tls
      hosts:
        - wiki-api.example.com
```

**Setup cert-manager:**

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Certificate will be auto-created and renewed
```

**Benefits:**
- ✅ Free certificates
- ✅ Automatic renewal (every 60 days)
- ✅ Widely trusted CA
- ✅ No manual management

### 2. Rate Limiting

Protect against abuse and DDoS attacks:

```yaml
ingress:
  annotations:
    # Limit to 100 requests per second per IP
    nginx.ingress.kubernetes.io/rate-limit: "100"
    
    # Burst allows temporary spikes
    nginx.ingress.kubernetes.io/limit-burst-multiplier: "5"
    
    # Connection limit per IP
    nginx.ingress.kubernetes.io/limit-connections: "10"
```

**Different limits per path:**

```yaml
# Apply to specific paths
nginx.ingress.kubernetes.io/configuration-snippet: |
  location /api {
    limit_req zone=api burst=20 nodelay;
  }
  
  location /grafana {
    limit_req zone=grafana burst=10 nodelay;
  }
```

### 3. Authentication and Authorization

#### Basic Authentication:

```bash
# Create htpasswd file
htpasswd -c auth admin

# Create secret
kubectl create secret generic basic-auth --from-file=auth

# Add to Ingress
ingress:
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
```

#### OAuth2 Proxy (SSO):

```yaml
# Use oauth2-proxy for Google/GitHub/Okta SSO
ingress:
  annotations:
    nginx.ingress.kubernetes.io/auth-url: "https://oauth2.example.com/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://oauth2.example.com/oauth2/start"
```

**Benefits:**
- ✅ Single sign-on (SSO)
- ✅ Centralized authentication
- ✅ Works with existing identity providers
- ✅ Audit trail

#### IP Whitelisting:

```yaml
# Allow only specific IPs
ingress:
  annotations:
    nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,172.16.0.0/12"
```

### 4. Web Application Firewall (WAF)

Protect against common web attacks:

```yaml
ingress:
  annotations:
    # Enable ModSecurity WAF
    nginx.ingress.kubernetes.io/enable-modsecurity: "true"
    nginx.ingress.kubernetes.io/enable-owasp-core-rules: "true"
    
    # Custom rules
    nginx.ingress.kubernetes.io/modsecurity-snippet: |
      SecRuleEngine On
      SecRule REQUEST_HEADERS:User-Agent "scanner" "id:1001,deny,status:403"
```

**What WAF protects against:**
- SQL injection
- Cross-site scripting (XSS)
- Local file inclusion
- Remote code execution
- Known vulnerability exploits

### 5. High Availability

Run multiple Ingress Controller replicas:

```bash
# For nginx ingress controller
kubectl scale deployment ingress-nginx-controller \
  --replicas=3 \
  -n ingress-nginx

# Verify
kubectl get pods -n ingress-nginx
```

**Benefits:**
- ✅ No single point of failure
- ✅ Zero-downtime updates
- ✅ Better performance (load distribution)
- ✅ Automatic failover

### 6. Monitoring and Logging

#### Prometheus Metrics:

```yaml
# nginx-ingress exposes metrics
ingress:
  annotations:
    nginx.ingress.kubernetes.io/enable-prometheus-metrics: "true"
```

**Access metrics:**
```bash
# Port-forward to controller
kubectl port-forward -n ingress-nginx <controller-pod> 10254:10254

# Scrape metrics
curl http://localhost:10254/metrics
```

**Key metrics to monitor:**
- `nginx_ingress_controller_requests`: Total requests
- `nginx_ingress_controller_request_duration_seconds`: Latency
- `nginx_ingress_controller_response_size`: Response sizes
- `nginx_ingress_controller_ssl_expire_time_seconds`: Certificate expiry

#### Access Logs:

```bash
# View ingress controller logs
kubectl logs -n ingress-nginx <controller-pod> -f

# Example log entry:
# 192.168.1.100 - - [31/Jan/2026:10:30:15 +0000] "GET /grafana HTTP/1.1" 200 12345 "-" "Mozilla/5.0"
```

**Structured logging:**
```yaml
# In ConfigMap for ingress-controller
data:
  log-format-upstream: '{"time": "$time_iso8601", "remote_addr": "$remote_addr", "request": "$request", "status": $status}'
```

### 7. Security Headers

Add security headers to responses:

```yaml
ingress:
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: DENY";
      more_set_headers "X-Content-Type-Options: nosniff";
      more_set_headers "X-XSS-Protection: 1; mode=block";
      more_set_headers "Referrer-Policy: strict-origin-when-cross-origin";
      more_set_headers "Strict-Transport-Security: max-age=31536000; includeSubDomains";
```

**What each does:**
- **X-Frame-Options**: Prevents clickjacking
- **X-Content-Type-Options**: Prevents MIME sniffing
- **X-XSS-Protection**: XSS filter in older browsers
- **Referrer-Policy**: Controls referrer information
- **Strict-Transport-Security**: Forces HTTPS (HSTS)

### 8. CORS Configuration

If you need cross-origin requests:

```yaml
ingress:
  annotations:
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://frontend.example.com"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE"
    nginx.ingress.kubernetes.io/cors-allow-headers: "Authorization, Content-Type"
```

### 9. Canary Deployments

Gradual rollouts with traffic splitting:

```yaml
# Primary Ingress (90% traffic)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wiki-chart-ingress
spec:
  # ... normal config

---
# Canary Ingress (10% traffic)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wiki-chart-ingress-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"
spec:
  # ... same host/path, different backend (new version)
```

### 10. Regular Maintenance

**Certificate Renewal:**
```bash
# Check certificate expiry
kubectl get certificate

# If using cert-manager, renewal is automatic
# Manual renewal:
kubectl delete secret wiki-api-tls
# cert-manager will recreate
```

**Update Ingress Controller:**
```bash
# Check current version
kubectl get deployment -n ingress-nginx ingress-nginx-controller -o yaml | grep image:

# Update to latest
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
```

**Security Audits:**
```bash
# Scan for vulnerabilities
kubesec scan ingress.yaml

# Check configuration
kubectl get ingress wiki-chart-ingress -o yaml | grep -i security
```

---

## Next Steps (Phase 10 Preview)

Now that our application is fully accessible externally with production-ready Ingress, here are potential areas for Phase 10:

### Option 1: CI/CD Pipeline

**Automate deployment:**
- GitHub Actions or GitLab CI
- Automated testing (unit, integration, e2e)
- Docker image building and pushing
- Automated Helm deployment
- Rollback on failure

**Benefits:**
- Faster deployments
- Reduced human error
- Consistent process
- Better quality through automated testing

### Option 2: Advanced Monitoring and Alerting

**Expand observability:**
- Custom Grafana dashboards for business metrics
- Prometheus AlertManager configuration
- Slack/email/PagerDuty integration
- SLA monitoring and reporting
- Distributed tracing (Jaeger/Tempo)

**Benefits:**
- Proactive issue detection
- Faster incident response
- Better understanding of system behavior
- Data-driven decisions

### Option 3: Infrastructure as Code (IaC)

**Terraform/Pulumi:**
- Provision Kubernetes cluster
- Configure cloud resources (LoadBalancer, DNS, certificates)
- Manage infrastructure versions
- Multi-environment support (dev/staging/prod)

**Benefits:**
- Reproducible infrastructure
- Version-controlled infrastructure
- Easy environment replication
- Disaster recovery

### Option 4: Service Mesh (Istio/Linkerd)

**Advanced traffic management:**
- mTLS between services
- Advanced routing and traffic splitting
- Circuit breaking and retries
- Detailed service-to-service observability

**Benefits:**
- Enhanced security
- Better reliability
- Fine-grained traffic control
- Deep insights

### Option 5: GitOps with ArgoCD/Flux

**Declarative deployment:**
- Git as source of truth
- Automatic sync from Git to cluster
- Easy rollbacks (Git revert)
- Audit trail via Git history

**Benefits:**
- Simplified deployments
- Better collaboration
- Full deployment history
- Disaster recovery

### Option 6: Scalability and Performance

**Horizontal Pod Autoscaling:**
- Auto-scale based on CPU/memory
- Custom metrics (requests per second)
- Cluster autoscaling

**Database optimization:**
- Read replicas
- Connection pooling
- Query optimization
- Caching layer (Redis)

**Benefits:**
- Handle traffic spikes
- Cost optimization (scale down when idle)
- Better performance
- Higher availability

---

## Summary

### What We Accomplished

In Phase 9, we:

1. ✅ **Created Ingress resource** with path-based routing
2. ✅ **Exposed three services** externally (FastAPI, Grafana, Prometheus)
3. ✅ **Configured path rewriting** for proper routing
4. ✅ **Added production annotations** (headers, timeouts, etc.)
5. ✅ **Enabled TLS support** (configurable)
6. ✅ **Documented thoroughly** with troubleshooting guides

### Architecture Before vs After

**Before Phase 9 (Internal Only):**
```
┌─────────────────────────────────────────────────┐
│           Kubernetes Cluster                    │
│  ┌──────────────┐  ┌──────────────┐            │
│  │   FastAPI    │  │   Grafana    │            │
│  │ ClusterIP    │  │ ClusterIP    │            │
│  └──────────────┘  └──────────────┘            │
│  ┌──────────────┐  ┌──────────────┐            │
│  │ Prometheus   │  │  PostgreSQL  │            │
│  │ ClusterIP    │  │ ClusterIP    │            │
│  └──────────────┘  └──────────────┘            │
└─────────────────────────────────────────────────┘
         ❌ No external access
         (kubectl port-forward only)
```

**After Phase 9 (Externally Accessible):**
```
        External User (Browser/API Client)
                       │
                       │ https://miro.medium.com/1*nEg52ecNa6ph_oJAmzrOqw.gif
                       │
                       ▼
┌─────────────────────────────────────────────────┐
│           Kubernetes Cluster                    │
│  ┌────────────────────────────────────────┐    │
│  │   Ingress Controller (nginx)           │    │
│  │   - Receives external traffic          │    │
│  │   - Routes based on path               │    │
│  │   - Handles SSL/TLS                    │    │
│  └───┬──────────────┬──────────────┬──────┘    │
│      │/             │/grafana      │/prometheus│
│      ▼              ▼              ▼            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │ FastAPI  │  │ Grafana  │  │Prometheus│     │
│  │ClusterIP │  │ClusterIP │  │ClusterIP │     │
│  └────┬─────┘  └──────────┘  └────┬─────┘     │
│       │                            │           │
│       ▼                            ▼           │
│  ┌──────────────┐            Scrape targets   │
│  │ PostgreSQL   │                              │
│  │  ClusterIP   │                              │
│  └──────────────┘                              │
└─────────────────────────────────────────────────┘
         ✅ Full external access
         (Production-ready deployment)
```

### Key Learnings

1. **Ingress vs Ingress Controller**: Ingress is the config, Controller does the work
2. **Path Rewriting**: Essential for hosting apps at subpaths
3. **TLS Termination**: Centralized SSL at Ingress level
4. **Annotations**: nginx-specific features for production needs
5. **Production Readiness**: Authentication, rate limiting, monitoring

### Files Created

```
bespoke-labs/
├── wiki-chart/
│   ├── templates/
│   │   └── ingress.yaml          ← New: Ingress resource
│   └── values.yaml                ← Already had ingress config
└── PHASE9_INGRESS.md              ← New: This documentation
```

### Testing Checklist

- [ ] Ingress Controller installed and running
- [ ] DNS configured (wiki-api.local in /etc/hosts)
- [ ] Ingress has ADDRESS assigned
- [ ] FastAPI accessible at http://wiki-api.local/
- [ ] Grafana accessible at http://wiki-api.local/grafana
- [ ] Prometheus accessible at http://wiki-api.local/prometheus
- [ ] Path rewriting works (APIs at subpaths work correctly)
- [ ] All backend services healthy
- [ ] End-to-end test passes (create article, check metrics)

---

## Conclusion

Congratulations! You now have a **production-ready, externally accessible** application with:

- ✅ **Unified access point**: Single domain for all services
- ✅ **Clean URLs**: Path-based routing without port numbers
- ✅ **Production features**: TLS support, rate limiting, authentication
- ✅ **Monitoring stack**: Grafana and Prometheus accessible externally
- ✅ **Scalable architecture**: Ready for high availability and load balancing

Your Wikipedia-like API service is now deployable to any Kubernetes cluster and accessible to real users!

**The journey:**
- **Phase 1-3**: Application core (FastAPI, PostgreSQL, Docker)
- **Phase 4**: Kubernetes packaging (Helm)
- **Phase 5-6**: Core services (Database, API)
- **Phase 7-8**: Observability (Prometheus, Grafana)
- **Phase 9**: External access (Ingress) ← You are here
- **Phase 10**: Choose your next adventure (CI/CD, advanced monitoring, GitOps, etc.)

This project demonstrates modern DevOps practices and prepares you for real-world production deployments. Each phase built on the previous ones, creating a complete, production-ready system.

**Next**: Review Phase 10 options and decide what to implement next based on your learning goals or production needs!

---

**Questions or Issues?**

Refer to:
- Troubleshooting Guide (above)
- nginx Ingress documentation: https://kubernetes.github.io/ingress-nginx/
- Kubernetes Ingress concepts: https://kubernetes.io/docs/concepts/services-networking/ingress/
- cert-manager documentation: https://cert-manager.io/docs/

Happy deploying! 🚀
