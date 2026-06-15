#!/usr/bin/env bash
# Provision the whole stack from scratch on a local minikube cluster:
#   - minikube + metrics-server   (cluster + CPU/RAM metrics)
#   - demo workloads              (something to look at)
#   - Headlamp                    (Kubernetes management dashboard)
#   - VPA recommender + Goldilocks (resource rightsizing recommendations)
#
# Idempotent: safe to re-run. Requires: minikube, kubectl, helm.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> 1/6  Starting minikube + metrics-server"
minikube status >/dev/null 2>&1 || minikube start --cpus=4 --memory=6144
minikube addons enable metrics-server >/dev/null

echo "==> 2/6  Deploying demo workloads"
kubectl apply -f demo-workloads.yaml

echo "==> 3/6  Adding Helm repos"
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/ >/dev/null 2>&1 || true
helm repo add fairwinds-stable https://charts.fairwinds.com/stable >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "==> 4/6  Installing Headlamp (management dashboard)"
helm upgrade --install headlamp headlamp/headlamp --namespace headlamp --create-namespace >/dev/null
# Give Headlamp's service account read/write visibility into the whole cluster.
kubectl create clusterrolebinding headlamp-admin \
  --clusterrole=cluster-admin --serviceaccount=headlamp:headlamp \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "==> 5/6  Installing VPA recommender + Goldilocks (rightsizing)"
# Recommender-only: the admission-controller/updater need a webhook cert hook
# that is flaky on minikube, and Goldilocks only needs the recommender anyway.
helm upgrade --install vpa fairwinds-stable/vpa --namespace vpa --create-namespace \
  --set updater.enabled=false \
  --set admissionController.enabled=false \
  --set recommender.enabled=true >/dev/null
helm upgrade --install goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks --create-namespace >/dev/null

echo "==> 6/6  Waiting for everything to be ready"
kubectl -n headlamp   rollout status deploy/headlamp             --timeout=180s
kubectl -n vpa        rollout status deploy/vpa-recommender       --timeout=180s
kubectl -n goldilocks rollout status deploy/goldilocks-dashboard  --timeout=180s

cat <<'DONE'

Done. Now open the dashboards:

  ./dashboards.sh up        # start port-forwards
  ./dashboards.sh token     # Headlamp login token

  Headlamp   -> http://localhost:8091   (paste the token)
  Goldilocks -> http://localhost:8092/namespaces  (click the "demo" namespace)

Note: Goldilocks needs a few minutes of metrics history before its
recommendations populate. Re-open the page if a workload shows no data yet.
DONE
