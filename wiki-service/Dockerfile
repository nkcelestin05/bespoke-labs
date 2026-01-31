# ============================================================================
# Phase 3: Production-Ready Dockerfile for FastAPI Wiki Service
# ============================================================================
# This Dockerfile follows Docker best practices for security, efficiency,
# and maintainability in a Kubernetes environment.
# ============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Base Image Selection
# -----------------------------------------------------------------------------
# Using python:3.13-slim for minimal size while maintaining functionality
# - 'slim' variant excludes unnecessary packages (reduces attack surface)
# - Python 3.13 provides latest performance improvements and security patches
# - Base image size: ~50MB vs ~300MB for full python:3.13
FROM python:3.13-slim AS base

# -----------------------------------------------------------------------------
# Stage 2: Build Arguments and Environment Variables
# -----------------------------------------------------------------------------
# Set Python environment variables for production
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# PYTHONUNBUFFERED=1: Ensures logs are immediately flushed to stdout/stderr
#   - Critical for Kubernetes log collection
#   - Prevents log loss during container crashes

# PYTHONDONTWRITEBYTECODE=1: Prevents Python from creating .pyc files
#   - Reduces container size
#   - Improves security (no bytecode artifacts)

# PIP_NO_CACHE_DIR=1: Disables pip cache
#   - Reduces image size by ~50-100MB
#   - Cache not needed in immutable containers

# PIP_DISABLE_PIP_VERSION_CHECK=1: Skips pip version check
#   - Faster builds
#   - Reduces network dependency

# -----------------------------------------------------------------------------
# Stage 3: System Dependencies
# -----------------------------------------------------------------------------
# Install only essential system packages required for PostgreSQL connectivity
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Required for PostgreSQL client libraries
    libpq-dev \
    # Required for building Python extensions
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Security best practice: Remove apt cache to reduce image size and attack surface
# --no-install-recommends: Excludes suggested packages (saves ~100MB)

# -----------------------------------------------------------------------------
# Stage 4: Application User Creation
# -----------------------------------------------------------------------------
# Create non-root user for running the application
# CRITICAL SECURITY PRACTICE: Never run containers as root
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Benefits:
# - Limits damage from container escape vulnerabilities
# - Required by many Kubernetes security policies (PodSecurityStandards)
# - Follows principle of least privilege

# -----------------------------------------------------------------------------
# Stage 5: Working Directory Setup
# -----------------------------------------------------------------------------
WORKDIR /app

# Sets the working directory for all subsequent commands
# All application files will be copied here

# -----------------------------------------------------------------------------
# Stage 6: Dependency Installation
# -----------------------------------------------------------------------------
# Copy requirements.txt first (Docker layer caching optimization)
COPY --chown=appuser:appuser requirements.txt .

# Layer caching optimization:
# - Dependencies change less frequently than application code
# - Copying requirements.txt separately allows Docker to cache this layer
# - Subsequent builds only reinstall dependencies if requirements.txt changes
# - Typical time savings: 30-60 seconds per build

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# --no-cache-dir: Prevents pip from caching packages (saves ~100MB)
# Installing as root here, but files will be owned by appuser

# -----------------------------------------------------------------------------
# Stage 7: Application Code Copy
# -----------------------------------------------------------------------------
# Copy application code with proper ownership
COPY --chown=appuser:appuser ./app /app/app

# --chown=appuser:appuser: Sets file ownership during copy
# - Prevents permission issues when running as non-root
# - More efficient than chown after copy

# Directory structure inside container:
# /app/
# ├── requirements.txt
# └── app/
#     ├── __init__.py
#     ├── main.py
#     ├── database.py
#     ├── models.py
#     ├── schemas.py
#     └── metrics.py

# -----------------------------------------------------------------------------
# Stage 8: Port Exposure
# -----------------------------------------------------------------------------
# Expose port 8000 for the FastAPI application
EXPOSE 8000

# Documentation only - doesn't actually open the port
# Kubernetes Service will map this port
# FastAPI/Uvicorn will listen on this port

# -----------------------------------------------------------------------------
# Stage 9: Health Check Configuration
# -----------------------------------------------------------------------------
# Configure container health check for /health endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

# Health check parameters explained:
# --interval=30s: Check every 30 seconds
# --timeout=10s: Fail if check takes longer than 10 seconds
# --start-period=40s: Grace period for application startup
# --retries=3: Mark unhealthy after 3 consecutive failures

# Why this matters:
# - Kubernetes uses this for liveness/readiness probes
# - Automatic container restart if unhealthy
# - Prevents routing traffic to unhealthy containers

# -----------------------------------------------------------------------------
# Stage 10: User Switch
# -----------------------------------------------------------------------------
# Switch to non-root user
USER appuser

# All subsequent commands and container runtime will use this user
# Critical security practice for production deployments

# -----------------------------------------------------------------------------
# Stage 11: Container Startup Command
# -----------------------------------------------------------------------------
# Run uvicorn with production-ready settings
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

# Command breakdown:
# - uvicorn: ASGI server for FastAPI
# - app.main:app: Python module path to FastAPI application
# - --host 0.0.0.0: Listen on all network interfaces (required for containers)
# - --port 8000: Listen on port 8000 (matches EXPOSE)

# Why 0.0.0.0 and not localhost:
# - Container networking requires binding to all interfaces
# - Kubernetes needs to route traffic from outside the container
# - localhost (127.0.0.1) only allows internal connections

# Production considerations:
# - No --reload flag (development only)
# - No --workers flag (handled by Kubernetes horizontal scaling)
# - Single worker per pod is recommended for Kubernetes

# ============================================================================
# Build and Run Instructions
# ============================================================================
#
# Build the image:
#   docker build -t wiki-service:latest .
#
# Run locally (without database):
#   docker run -p 8000:8000 wiki-service:latest
#
# Run with PostgreSQL:
#   docker run -p 8000:8000 \
#     -e DB_USER=postgres \
#     -e DB_PASSWORD=postgres \
#     -e DB_HOST=host.docker.internal \
#     -e DB_PORT=5432 \
#     -e DB_NAME=wikidb \
#     wiki-service:latest
#
# ============================================================================
