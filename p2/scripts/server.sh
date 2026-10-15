#!/bin/bash
# Install K3s in server mode, then deploy the 3 apps and the Ingress of confs/.
# Usage: server.sh <node_ip>
set -euo pipefail

NODE_IP="$1"
CONFS="/vagrant/confs"

# Interface carrying NODE_IP, so flannel does not pick the NAT one
IFACE=$(ip -o -4 addr show | awk -v ip="$NODE_IP" '$4 ~ "^"ip"/" {print $2}')

# curl is needed to download K3s; minimal boxes may not ship it
if ! command -v curl > /dev/null; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl
fi

# --write-kubeconfig-mode=644: kubectl usable by the vagrant user, without sudo
K3S_ARGS="server --node-ip=$NODE_IP --flannel-iface=$IFACE --write-kubeconfig-mode=644"
# Keep traefik (our Ingress controller) and servicelb (exposes traefik on
# port 80 of the node). With 1 CPU / 1024 MB (K3s asks 2 GB for a server),
# skip what we do not use: metrics, local volumes, network policies.
K3S_ARGS="$K3S_ARGS --disable=metrics-server,local-storage --disable-network-policy"

if ! command -v k3s > /dev/null; then
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="$K3S_ARGS" sh -
fi

# Wait for the API before sending the manifests
until kubectl get nodes > /dev/null 2>&1; do
  sleep 2
done

# "apply" creates or updates: safe to run several times
kubectl apply -f "$CONFS"

echo "K3s server ready on $NODE_IP ($IFACE), apps deployed"
