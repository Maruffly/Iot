#!/bin/bash
# Install the tools of Part 3 on a fresh Debian VM: Docker, kubectl and k3d.
# Run as a regular user with sudo rights; safe to run several times.
# Usage: install.sh
set -euo pipefail

# --------------------------------------------------------------- Docker
# Official apt repository (https://docs.docker.com/engine/install/debian/)
if ! command -v docker > /dev/null; then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<SOURCES
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
SOURCES
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    docker-ce docker-ce-cli containerd.io
fi

# Use docker without sudo (effective at the next login; deploy.sh handles
# the current session)
sudo usermod -aG docker "$USER"

# -------------------------------------------------------------- kubectl
# Latest stable release (https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
if ! command -v kubectl > /dev/null; then
  VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
  ARCH=$(dpkg --print-architecture)
  TMP=$(mktemp -d)
  curl -fsSL -o "$TMP/kubectl" "https://dl.k8s.io/release/$VERSION/bin/linux/$ARCH/kubectl"
  curl -fsSL -o "$TMP/kubectl.sha256" "https://dl.k8s.io/release/$VERSION/bin/linux/$ARCH/kubectl.sha256"
  echo "$(cat "$TMP/kubectl.sha256")  $TMP/kubectl" | sha256sum --check --quiet
  sudo install -o root -g root -m 0755 "$TMP/kubectl" /usr/local/bin/kubectl
  rm -rf "$TMP"
fi

# ------------------------------------------------------------------ k3d
# Official install script, latest release (https://k3d.io/stable/)
if ! command -v k3d > /dev/null; then
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

docker --version
kubectl version --client
k3d version
