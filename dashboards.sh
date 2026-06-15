#!/usr/bin/env bash
# Helper for the local Kubernetes playground (minikube + Headlamp + Goldilocks).
# Usage:
#   ./dashboards.sh up      # start cluster (if needed) + open port-forwards
#   ./dashboards.sh down    # stop port-forwards (cluster keeps running)
#   ./dashboards.sh token   # print a fresh Headlamp login token
#   ./dashboards.sh stop    # stop the whole minikube cluster
set -euo pipefail

HEADLAMP_PORT=8091
GOLDILOCKS_PORT=8092

up() {
  minikube status >/dev/null 2>&1 || minikube start
  echo "Starting port-forwards..."
  pkill -f "port-forward.*svc/headlamp" 2>/dev/null || true
  pkill -f "port-forward.*svc/goldilocks-dashboard" 2>/dev/null || true
  sleep 1
  nohup kubectl -n headlamp   port-forward svc/headlamp           ${HEADLAMP_PORT}:80   >/tmp/headlamp-pf.log   2>&1 &
  nohup kubectl -n goldilocks port-forward svc/goldilocks-dashboard ${GOLDILOCKS_PORT}:80 >/tmp/goldilocks-pf.log 2>&1 &
  sleep 3
  echo
  echo "  Headlamp   -> http://localhost:${HEADLAMP_PORT}   (paste token from: ./dashboards.sh token)"
  echo "  Goldilocks -> http://localhost:${GOLDILOCKS_PORT}/namespaces"
}

down() {
  pkill -f "port-forward.*svc/headlamp" 2>/dev/null || true
  pkill -f "port-forward.*svc/goldilocks-dashboard" 2>/dev/null || true
  echo "Port-forwards stopped."
}

token() { kubectl create token headlamp --namespace headlamp --duration=168h; }

case "${1:-up}" in
  up)    up ;;
  down)  down ;;
  token) token ;;
  stop)  down; minikube stop ;;
  *) echo "usage: $0 {up|down|token|stop}"; exit 1 ;;
esac
