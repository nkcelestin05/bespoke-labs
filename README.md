# 🚀 Bespoke Labs Assignment - Phase 1: Wiki Service Kubernetes Deployment

## 📋 Overview

This repository contains the Phase 1 implementation of the Bespoke Labs take-home assignment. The goal is to transform a FastAPI application from a development setup (SQLite) into a production-ready, cloud-native microservices architecture deployed on Kubernetes with monitoring capabilities.

## 🎯 Project Objectives

### Phase 1 Goals
- ✅ Set up proper project structure separating application code and infrastructure
- ✅ Prepare FastAPI application for containerization
- ✅ Create foundation for Kubernetes/Helm deployment
- 🔄 Migrate from SQLite to PostgreSQL (upcoming)
- 🔄 Containerize application with Docker (upcoming)
- 🔄 Deploy to Kubernetes with Helm charts (upcoming)
- 🔄 Set up monitoring with Prometheus & Grafana (upcoming)

## 📁 Project Structure

```
assignment-part1/
├── wiki-service/              # FastAPI Application
│   ├── app/                   # Application code
│   │   ├── __init__.py       # Package initialization
│   │   ├── main.py           # FastAPI application entry point
│   │   ├── database.py       # Database configuration
│   │   ├── models.py         # SQLAlchemy models
│   │   ├── schemas.py        # Pydantic schemas
│   │   └── metrics.py        # Prometheus metrics
│   ├── main.py               # Application runner
│   ├── pyproject.toml        # Python dependencies (UV format)
│   ├── uv.lock               # Dependency lock file
│   ├── .python-version       # Python version specification
│   └── test_api.sh           # API testing script
│
└── wiki-chart/               # Kubernetes/Helm Configuration
    ├── templates/            # Kubernetes resource templates (upcoming)
    └── dashboards/           # Grafana dashboard configs (upcoming)
```

## 🛠️ Technology Stack

### Application Layer
- **Framework**: FastAPI (modern, fast web framework)
- **Database**: SQLite (development) → PostgreSQL (production)
- **ORM**: SQLAlchemy (database abstraction)
- **Validation**: Pydantic (data validation)
- **Metrics**: Prometheus client library

### Infrastructure Layer (Upcoming)
- **Containerization**: Docker
- **Orchestration**: Kubernetes
- **Package Manager**: Helm
- **Monitoring**: Prometheus + Grafana
- **Ingress**: Kubernetes Ingress Controller

## 🚀 Getting Started

### Prerequisites
- Python 3.13+
- UV package manager (or pip)
- Docker (for containerization)
- Kubernetes cluster (Minikube, Kind, or cloud provider)
- kubectl CLI tool
- Helm 3+

### Local Development Setup

1. **Navigate to the wiki-service directory**:
   ```bash
   cd wiki-service
   ```

2. **Install dependencies** (using UV):
   ```bash
   uv sync
   ```

   Or using pip:
   ```bash
   pip install -e .
   ```

3. **Run the application**:
   ```bash
   python main.py
   ```
   
   Or with uvicorn directly:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

4. **Test the API**:
   ```bash
   ./test_api.sh
   ```

5. **Access the application**:
   - API: http://localhost:8000
   - Interactive docs: http://localhost:8000/docs
   - Metrics: http://localhost:8000/metrics

## 📊 API Endpoints

### Users
- `GET /users` - List all users
- `POST /users` - Create a new user
- `GET /users/{user_id}` - Get user by ID
- `PUT /users/{user_id}` - Update user
- `DELETE /users/{user_id}` - Delete user

### Posts
- `GET /posts` - List all posts
- `POST /posts` - Create a new post
- `GET /posts/{post_id}` - Get post by ID
- `PUT /posts/{post_id}` - Update post
- `DELETE /posts/{post_id}` - Delete post

### Monitoring
- `GET /metrics` - Prometheus metrics endpoint

## 🔄 Next Steps (Upcoming Phases)

### Phase 2: Database Migration
- [ ] Replace SQLite with PostgreSQL
- [ ] Update database connection configuration
- [ ] Test CRUD operations with PostgreSQL

### Phase 3: Containerization
- [ ] Create Dockerfile for wiki-service
- [ ] Build Docker image
- [ ] Test container locally

### Phase 4-6: Kubernetes Deployment
- [ ] Create Kubernetes manifests (Deployment, Service, ConfigMap, Secret)
- [ ] Convert to Helm chart
- [ ] Deploy to Kubernetes cluster

### Phase 7-8: Monitoring
- [ ] Deploy Prometheus
- [ ] Deploy Grafana
- [ ] Create custom dashboards

### Phase 9-10: Ingress & Testing
- [ ] Configure Ingress controller
- [ ] Set up routing rules
- [ ] End-to-end testing

## 🎓 Learning Resources

### FastAPI
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [SQLAlchemy Documentation](https://docs.sqlalchemy.org/)

### Kubernetes
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)

### Monitoring
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

## 📝 Development Notes

### Separation of Concerns
This project structure follows the principle of separation of concerns:
- **Application Code** (`wiki-service/`): Contains all business logic and application code
- **Infrastructure Code** (`wiki-chart/`): Contains all deployment and configuration

This separation allows:
- Independent versioning of code and infrastructure
- Easier collaboration between dev and ops teams
- Better testing and deployment workflows

### Design Decisions
- **FastAPI**: Chosen for its modern async capabilities and automatic OpenAPI documentation
- **PostgreSQL**: Production-grade relational database with strong consistency
- **Kubernetes**: Industry-standard container orchestration
- **Helm**: Simplifies Kubernetes deployments with templating and versioning
- **Prometheus + Grafana**: Industry-standard monitoring stack

## 🤝 Contributing

This is a take-home assignment repository. For questions or issues, please reach out to the assignment coordinator.

## 📄 License

This project is part of the Bespoke Labs technical assessment.

---

**Status**: Phase 1 Complete ✅ | Last Updated: January 31, 2026
