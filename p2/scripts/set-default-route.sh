#!/bin/bash
# Make the host-only interface (192.168.56.x) the "main" interface of the VM.
#
# VirtualBox gives every Vagrant VM a NAT interface (10.0.2.15) that owns the
# default route. We move the default route to the host-only interface, so that
# `ip a show $(ip route | grep default | awk '{print $5}')` shows our IP.
# The host-only network has no Internet access, so two more specific routes
# (0.0.0.0/1 + 128.0.0.0/1 cover every address) keep real traffic on the NAT.
#
# Routes are not persistent: the Vagrantfile runs this script on every boot.
# Usage: set-default-route.sh <node_ip>
set -euo pipefail

NODE_IP="$1"
HOSTONLY_GW="192.168.56.1"   # host side of the VirtualBox host-only network

# Interface carrying NODE_IP (eth1, enp0s8... depending on the distribution)
IFACE=$(ip -o -4 addr show | awk -v ip="$NODE_IP" '$4 ~ "^"ip"/" {print $2}')
if [ -z "$IFACE" ]; then
  echo "No interface found with IP $NODE_IP" >&2
  exit 1
fi

# NAT gateway and interface: read from our /1 route if it already exists
# (script re-run), otherwise from the original default route.
NAT=$(ip route show 0.0.0.0/1)
[ -n "$NAT" ] || NAT=$(ip route show default)
NAT_GW=$(echo "$NAT" | awk '{for (i = 1; i < NF; i++) if ($i == "via") print $(i + 1)}' | head -n 1)
NAT_IF=$(echo "$NAT" | awk '{for (i = 1; i < NF; i++) if ($i == "dev") print $(i + 1)}' | head -n 1)
if [ -z "$NAT_GW" ] || [ "$NAT_IF" = "$IFACE" ]; then
  echo "Cannot find the NAT gateway" >&2
  exit 1
fi

# "replace" = add or update: safe to run several times
ip route replace 0.0.0.0/1   via "$NAT_GW" dev "$NAT_IF"
ip route replace 128.0.0.0/1 via "$NAT_GW" dev "$NAT_IF"
ip route replace default     via "$HOSTONLY_GW" dev "$IFACE"

echo "Default route now on $IFACE ($NODE_IP), Internet still through $NAT_IF"
