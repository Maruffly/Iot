#!/bin/bash
# Install K3s in server (controller) mode and share the join token with the
# worker through the synced folder /vagrant.
# Usage: server.sh <node_ip>
set -euo pipefail

NODE_IP="$1"
TOKEN_SRC="/var/lib/rancher/k3s/server/node-token"
TOKEN_DST="/vagrant/confs/node-token"
CONFIG="/vagrant/confs/server.yaml"

# Interface carrying NODE_IP, so flannel does not pick the NAT one
IFACE=$(ip -o -4 addr show | awk -v ip="$NODE_IP" '$4 ~ "^"ip"/" {print $2}')

# curl is needed to download K3s; minimal boxes may not ship it
if ! command -v curl > /dev/null; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl
fi

# Static options live in confs/server.yaml, read by K3s at every start
install -D -m 644 "$CONFIG" /etc/rancher/k3s/config.yaml

if ! command -v k3s > /dev/null; then
  curl -sfL https://get.k3s.io | \
    INSTALL_K3S_EXEC="server --node-ip=$NODE_IP --flannel-iface=$IFACE" \
    sh -
fi

# The token file is written once K3s has started
until [ -f "$TOKEN_SRC" ]; do
  sleep 2
done
cp "$TOKEN_SRC" "$TOKEN_DST"

echo "K3s server ready on $NODE_IP ($IFACE)"
