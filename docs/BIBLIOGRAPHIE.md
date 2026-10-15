# Bibliographie et documentation : Inception-of-Things

Ressources classées par thème. ★ = à lire en priorité pour le projet.
La documentation officielle prévaut toujours sur les tutoriels : versions et options évoluent vite.

---

## 1. Sujet et évaluation

- ★ Sujet officiel : `en.subject.pdf` (v4.0, racine du repo)
- ★ Fiche de correction : https://www.42evalhub.com/spec/inception-of-things
- Synthèse des exigences : [`SPECS.md`](./SPECS.md)

## 2. Vagrant

- ★ Documentation Vagrant : https://developer.hashicorp.com/vagrant/docs
- ★ Vagrantfile (syntaxe, multi-machine) : https://developer.hashicorp.com/vagrant/docs/vagrantfile et https://developer.hashicorp.com/vagrant/docs/multi-machine
- ★ Réseau privé (`private_network`) : https://developer.hashicorp.com/vagrant/docs/networking/private_network
- ★ Provisioning shell (`inline`, `path`, `env`, `args`) : https://developer.hashicorp.com/vagrant/docs/provisioning/shell
- Provider VirtualBox (`v.memory`, `v.cpus`, `v.name`, `customize`) : https://developer.hashicorp.com/vagrant/docs/providers/virtualbox/configuration
- Dossiers synchronisés (`/vagrant`) : https://developer.hashicorp.com/vagrant/docs/synced-folders
- SSH (`config.ssh.*`) : https://developer.hashicorp.com/vagrant/docs/vagrantfile/ssh_settings
- Catalogue de boxes : https://portal.cloud.hashicorp.com/vagrant/discover
- Boxes Bento (Chef), un standard de fait : https://github.com/chef/bento
- Images Vagrant officielles Debian : https://salsa.debian.org/cloud-team/debian-vagrant-images
- Provider libvirt (alternative à VirtualBox) : https://vagrant-libvirt.github.io/vagrant-libvirt/
- Livre : M. Hashimoto, *Vagrant: Up and Running*, O'Reilly, 2013 (ancien, mais les concepts restent valables)

## 3. Virtualisation et réseau des VMs

- Manuel VirtualBox, modes réseau (NAT, Host-only…) : https://www.virtualbox.org/manual/ch06.html
- Plages host-only autorisées (`/etc/vbox/networks.conf`, défaut `192.168.56.0/21`) : https://www.virtualbox.org/manual/ch06.html#network_hostonly
- Virtualisation imbriquée (nécessaire dans la VM de 42) : https://www.virtualbox.org/manual/ch09.html#nested-virt
- `ip` (iproute2) : `man ip-address`, `man ip-route` et https://man7.org/linux/man-pages/man8/ip.8.html
- Noms d'interfaces prévisibles (`enp0s8`…) : https://systemd.io/PREDICTABLE_INTERFACE_NAMES/
- Debian 13 « trixie » (stable depuis le 09/08/2025) : https://www.debian.org/releases/trixie/ et https://www.debian.org/news/2025/20250809

## 4. K3s

- ★ Documentation K3s : https://docs.k3s.io/
- ★ Quick start (server et agent, `K3S_URL`, `K3S_TOKEN`) : https://docs.k3s.io/quick-start
- ★ Options d'installation (`INSTALL_K3S_EXEC`, variables d'env.) : https://docs.k3s.io/installation/configuration
- ★ CLI server (`--node-ip`, `--flannel-iface`, `--write-kubeconfig-mode`) : https://docs.k3s.io/cli/server
- CLI agent : https://docs.k3s.io/cli/agent
- Architecture (server/agent, datastore embarqué) : https://docs.k3s.io/architecture
- Tokens : https://docs.k3s.io/cli/token
- Services réseau embarqués (Traefik, ServiceLB, CoreDNS) : https://docs.k3s.io/networking/networking-services
- Options réseau (Flannel, multi-interfaces) : https://docs.k3s.io/networking/basic-network-options
- Accès au cluster et kubeconfig : https://docs.k3s.io/cluster-access
- Dépôt GitHub : https://github.com/k3s-io/k3s

## 5. Kubernetes (concepts et kubectl)

- ★ Composants d'un cluster : https://kubernetes.io/docs/concepts/overview/components/
- ★ Pods : https://kubernetes.io/docs/concepts/workloads/pods/
- ★ Deployments et réplicas : https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- ★ Services : https://kubernetes.io/docs/concepts/services-networking/service/
- ★ Ingress (règles host, `defaultBackend`) : https://kubernetes.io/docs/concepts/services-networking/ingress/
- ★ Namespaces : https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/
- ConfigMaps : https://kubernetes.io/docs/concepts/configuration/configmap/
- Labels et selectors : https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
- ★ Aide-mémoire kubectl : https://kubernetes.io/docs/reference/kubectl/quick-reference/
- Installer kubectl : https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
- Tutoriel interactif officiel : https://kubernetes.io/docs/tutorials/kubernetes-basics/
- Livres :
  - B. Burns, J. Beda, K. Hightower, L. Evenson, *Kubernetes: Up and Running*, 3ᵉ éd., O'Reilly, 2022
  - M. Lukša, *Kubernetes in Action*, 2ᵉ éd., Manning
  - N. Poulton, *The Kubernetes Book*, mis à jour chaque année

## 6. Traefik (Ingress Controller de K3s)

- Fournisseur Kubernetes Ingress : https://doc.traefik.io/traefik/providers/kubernetes-ingress/
- Routage : https://doc.traefik.io/traefik/routing/overview/
- Personnaliser Traefik dans K3s (HelmChartConfig) : https://docs.k3s.io/helm#customizing-packaged-components-with-helmchartconfig

## 7. K3d

- ★ Documentation K3d : https://k3d.io/
- ★ Exposer des services (`-p "8888:8888@loadbalancer"`) : https://k3d.io/stable/usage/exposing_services/
- Commandes (`k3d cluster create/delete/list`) : https://k3d.io/stable/usage/commands/
- Fichier de configuration de cluster : https://k3d.io/stable/usage/configfile/
- Dépôt GitHub : https://github.com/k3d-io/k3d

## 8. Docker

- ★ Installation Debian : https://docs.docker.com/engine/install/debian/
- Installation Ubuntu : https://docs.docker.com/engine/install/ubuntu/
- Post-installation (groupe `docker`) : https://docs.docker.com/engine/install/linux-postinstall/
- Tags d'images : https://docs.docker.com/reference/cli/docker/image/tag/
- Pousser sur Docker Hub : https://docs.docker.com/docker-hub/repos/
- ★ Image de Wil, `wil42/playground` (tags `v1`/`v2`, port 8888) : https://hub.docker.com/r/wil42/playground

## 9. Argo CD, GitOps et CI/CD

- ★ Documentation Argo CD : https://argo-cd.readthedocs.io/en/stable/
- ★ Getting Started (install, mot de passe initial, port-forward) : https://argo-cd.readthedocs.io/en/stable/getting_started/
- ★ Concepts clés (Application, sync, health…) : https://argo-cd.readthedocs.io/en/stable/core_concepts/
- ★ Configuration déclarative (`Application` en YAML) : https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/
- ★ Sync automatique (`prune`, `selfHeal`) : https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/
- Options de sync (`CreateNamespace=true`) : https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/
- Fréquence de polling et webhooks : https://argo-cd.readthedocs.io/en/stable/operator-manual/webhook/
- CLI argocd : https://argo-cd.readthedocs.io/en/stable/cli_installation/
- Releases : https://github.com/argoproj/argo-cd/releases (la branche 3.5.x était la plus récente à l'automne 2026 ; à revérifier)
- Principes GitOps (OpenGitOps / CNCF) : https://opengitops.dev/
- M. Fowler, « Continuous Integration » : https://martinfowler.com/articles/continuousIntegration.html
- CI/CD (vue d'ensemble) : https://about.gitlab.com/topics/ci-cd/
- Livres :
  - B. Yuen, A. Matyushentsev, T. Ekenstam, J. Suen, *GitOps and Kubernetes*, Manning, 2021
  - L. Costea, S. Economakis, *Argo CD in Practice*, Packt, 2022

## 10. Bonus : GitLab et Helm

- ★ Helm, installation et concepts : https://helm.sh/docs/intro/install/ et https://helm.sh/docs/intro/using_helm/
- ★ Chart GitLab : https://docs.gitlab.com/charts/
- Déploiement du chart : https://docs.gitlab.com/charts/installation/deployment/
- Options du chart : https://docs.gitlab.com/charts/installation/command-line-options/
- Exemples de values minimales : https://gitlab.com/gitlab-org/charts/gitlab/-/tree/master/examples
- Dépôt Helm : https://charts.gitlab.io
- Ajouter un repo privé ou HTTP dans Argo CD : https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/
- Releases GitLab : https://about.gitlab.com/releases/

## 11. Outils de confort (facultatifs)

- k9s (TUI Kubernetes) : https://k9scli.io/
- kubectx / kubens : https://github.com/ahmetb/kubectx
- ShellCheck (lint des scripts) : https://www.shellcheck.net/
