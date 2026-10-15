#!/bin/bash
# Install K3s in agent mode and join the server's cluster.
# Usage: agent.sh <server_ip> <node_ip>
set -euo pipefail

SERVER_IP="$1"
NODE_IP="$2"
TOKEN_FILE="/vagrant/confs/node-token"   # written by server.sh
CONFIG="/vagrant/confs/agent.yaml"

IFACE=$(ip -o -4 addr show | awk -v ip="$NODE_IP" '$4 ~ "^"ip"/" {print $2}')

# curl is needed to download K3s; minimal boxes may not ship it
if ! command -v curl > /dev/null; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl
fi

# The server is provisioned first, but wait anyway for its token and API
until [ -f "$TOKEN_FILE" ] && curl -sk "https://$SERVER_IP:6443" > /dev/null; do
  echo "Waiting for the K3s server at $SERVER_IP..."
  sleep 5
done

# Static options (server URL) live in confs/agent.yaml, read by K3s at every start
install -D -m 644 "$CONFIG" /etc/rancher/k3s/config.yaml

# K3S_TOKEN is saved by the installer in the service environment file
if ! command -v k3s > /dev/null; then
  curl -sfL https://get.k3s.io | \
    K3S_TOKEN="$(cat "$TOKEN_FILE")" \
    INSTALL_K3S_EXEC="agent --node-ip=$NODE_IP --flannel-iface=$IFACE" \
    sh -
fi

echo "K3s agent $NODE_IP ($IFACE) joined $SERVER_IP"
