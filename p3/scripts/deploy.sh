#!/bin/bash
# Create the k3d cluster, install Argo CD and hand the "dev" namespace over
# to Argo CD, which deploys the app from the public GitHub repo.
# Run after install.sh, as the same user; safe to run several times.
# Usage: deploy.sh
set -euo pipefail

CLUSTER="iot"
CONFS="$(dirname "$(realpath "$0")")/../confs"
ARGOCD_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

# Just added to the docker group by install.sh: not active before a new
# login, so rerun this script inside that group
if ! id -nG | grep -qw docker; then
  exec sg docker "$0"
fi

# K3s in Docker containers. Port 8888 of this machine goes to the k3d load
# balancer, then to the app Service (type LoadBalancer, port 8888).
# No Ingress (traefik) nor metrics needed here: skip them to save CPU/RAM.
if ! k3d cluster list "$CLUSTER" > /dev/null 2>&1; then
  k3d cluster create "$CLUSTER" -p "8888:8888@loadbalancer" \
    --k3s-arg "--disable=traefik,metrics-server@server:0"
fi

# Namespaces argocd and dev
kubectl apply -f "$CONFS/namespaces.yaml"

# Argo CD, latest stable release. --server-side: some CRDs are too big for
# the annotation written by a client-side apply.
kubectl apply -n argocd --server-side --force-conflicts -f "$ARGOCD_MANIFEST"
kubectl wait --for condition=established crd/applications.argoproj.io --timeout=60s
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=300s

# The Application: Argo CD now syncs the GitHub repo into namespace dev
kubectl apply -f "$CONFS/application.yaml"

echo "Waiting for the app on http://localhost:8888 ..."
for _ in $(seq 60); do
  if curl -fs http://localhost:8888/; then
    echo
    break
  fi
  sleep 5
done

PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)
cat <<INFO
Argo CD UI:
  kubectl port-forward svc/argocd-server -n argocd 8080:443
  https://localhost:8080   login: admin   password: $PASSWORD
INFO
