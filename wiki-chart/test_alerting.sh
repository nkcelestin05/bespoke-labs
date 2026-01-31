#!/usr/bin/env bash
set -euo pipefail

RELEASE=${1:-wiki}
NAMESPACE=${2:-default}

echo "Port-forwarding Prometheus service (release=$RELEASE namespace=$NAMESPACE)"
kubectl -n "$NAMESPACE" port-forward svc/${RELEASE}-prometheus 9090:9090 >/dev/null 2>&1 &
PF_PID=$!
trap 'kill $PF_PID' EXIT
sleep 1

echo "Fetching Prometheus alerting rules..."
curl -s http://localhost:9090/api/v1/rules | jq '.' || curl -s http://localhost:9090/api/v1/rules | head -n 200

echo "Fetching current alerts..."
curl -s http://localhost:9090/api/v1/alerts | jq '.' || curl -s http://localhost:9090/api/v1/alerts | head -n 200

# Note: To test FastAPI down alert, scale deployment to 0 and wait a few minutes:
# kubectl scale deployment/${RELEASE}-fastapi --replicas=0 -n ${NAMESPACE}
# Then run this script again and observe the FastAPIDown alert firing (if evaluation interval passed).

echo "Done."