# Phase 2: Database Migration - SQLite → PostgreSQL

## 🎯 Objective
Migrate the FastAPI application from SQLite to PostgreSQL to prepare for production deployment in Kubernetes.

---

## 📊 Changes Summary

### 1. **Modified: `wiki-service/app/database.py`**

#### What Changed:
- **Database driver**: `aiosqlite` → `asyncpg`
- **Connection string**: `sqlite+aiosqlite:///./app.db` → `postgresql+asyncpg://user:password@host:port/database`
- **Configuration**: Now uses environment variables for database credentials
- **Connection pooling**: Added pool configuration for better performance

#### Line-by-Line Breakdown:

```python
# OLD (SQLite):
DATABASE_URL = "sqlite+aiosqlite:///./app.db"

# NEW (PostgreSQL):
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "wikidb")

DATABASE_URL = f"postgresql+asyncpg://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
```

**Why?**
- **Environment variables** allow different configurations for dev/staging/production
- Kubernetes can inject these values via ConfigMaps/Secrets
- No hardcoded credentials in code
- Default values make local testing easier

#### Connection Pool Configuration:

```python
engine = create_async_engine(
    DATABASE_URL,
    echo=True,
    future=True,
    pool_pre_ping=True,      # NEW: Verify connections are alive
    pool_size=10,            # NEW: Maintain 10 active connections
    max_overflow=20          # NEW: Allow up to 20 extra connections
)
```

**Why?**
- `pool_pre_ping=True`: Prevents "connection lost" errors in Kubernetes
- `pool_size=10`: Reuses connections instead of creating new ones (faster)
- `max_overflow=20`: Handles traffic spikes gracefully

---

### 2. **Created: `wiki-service/requirements.txt`**

#### What It Contains:

| Package | Version | Purpose |
|---------|---------|---------|
| `fastapi` | ≥0.121.0 | Web framework |
| `uvicorn` | ≥0.38.0 | ASGI server |
| **`asyncpg`** | **≥0.30.0** | **PostgreSQL async driver (NEW)** |
| `sqlalchemy` | ≥2.0.44 | ORM |
| `greenlet` | ≥3.2.4 | SQLAlchemy async support |
| `pydantic` | ≥2.12.3 | Data validation |
| `prometheus-client` | ≥0.23.1 | Metrics |

#### What Was Removed:
- ❌ `aiosqlite` - No longer needed for PostgreSQL

**Why requirements.txt?**
- Docker uses `requirements.txt` for reproducible builds
- Simpler than `pyproject.toml` for containerized environments
- Industry standard for Python containers

---

## 🧪 Testing Locally

### Option 1: Using Docker (Recommended)

```bash
# Start PostgreSQL container
docker run -d \
  --name wiki-postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=wikidb \
  -p 5432:5432 \
  postgres:16-alpine

# Install dependencies
cd wiki-service
pip install -r requirements.txt

# Set environment variables
export DB_USER=postgres
export DB_PASSWORD=postgres
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=wikidb

# Run the application
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Option 2: Using Kubernetes (Phase 3+)

This will be covered when we deploy the Helm chart with PostgreSQL included.

---

## 🔐 Environment Variables Reference

| Variable | Default | Description | Kubernetes Source |
|----------|---------|-------------|-------------------|
| `DB_USER` | `postgres` | Database username | ConfigMap/Secret |
| `DB_PASSWORD` | `postgres` | Database password | **Secret** (encrypted) |
| `DB_HOST` | `localhost` | Database hostname | ConfigMap (service name) |
| `DB_PORT` | `5432` | Database port | ConfigMap |
| `DB_NAME` | `wikidb` | Database name | ConfigMap |

**Security Note:** In production:
- `DB_PASSWORD` must be stored in a Kubernetes Secret
- Never commit passwords to Git
- Use RBAC to restrict Secret access

---

## 📈 Benefits of This Migration

### Before (SQLite):
```
[FastAPI Pod 1] ──┐
                  ├─► app.db (file in pod filesystem)
[FastAPI Pod 2] ──┘
     ⚠️ Each pod has its own database file!
     ⚠️ Data lost when pods restart
```

### After (PostgreSQL):
```
[FastAPI Pod 1] ──┐
[FastAPI Pod 2] ──┼─► [PostgreSQL StatefulSet]
[FastAPI Pod 3] ──┘         │
                     [Persistent Volume]
     ✅ All pods share the same database
     ✅ Data persists across restarts
```

---

## 🚀 Next Steps (Phase 3)

1. **Create Dockerfile** for the FastAPI application
2. **Build and push** container image to registry
3. **Create Kubernetes manifests**:
   - Deployment for FastAPI
   - StatefulSet for PostgreSQL
   - Services for networking
   - ConfigMap for configuration
   - Secret for credentials
4. **Deploy with Helm** and test end-to-end

---

## 🔍 How to Verify Changes

### Check Database Connection:
```python
# Test script (test_db_connection.py)
import asyncio
from wiki-service.app.database import engine

async def test_connection():
    async with engine.begin() as conn:
        result = await conn.execute("SELECT version();")
        print(f"Connected to: {result.scalar()}")

asyncio.run(test_connection())
```

### Inspect Connection String:
```bash
cd wiki-service
python3 -c "from app.database import DATABASE_URL; print(DATABASE_URL)"
# Should show: postgresql+asyncpg://postgres:***@localhost:5432/wikidb
```

---

## 📚 Additional Resources

- [SQLAlchemy Async Documentation](https://docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html)
- [asyncpg Documentation](https://magicstack.github.io/asyncpg/)
- [PostgreSQL Docker Hub](https://hub.docker.com/_/postgres)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

---

## ✅ Phase 2 Completion Checklist

- [x] Modify `database.py` to use PostgreSQL
- [x] Add environment variable configuration
- [x] Create `requirements.txt` with asyncpg
- [x] Remove aiosqlite dependency
- [x] Document changes and rationale
- [ ] Test locally with PostgreSQL (user action)
- [ ] Push changes to GitHub (user action)
- [ ] Proceed to Phase 3: Containerization

---

**Status**: ✅ **Phase 2 Complete - Ready for Testing**
