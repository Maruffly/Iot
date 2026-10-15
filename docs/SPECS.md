# Inception-of-Things (IoT) — Spécifications

Sources :
- `en.subject.pdf`, version 4.0 (à la racine du repo)
- Fiche de correction : https://www.42evalhub.com/spec/inception-of-things (données brutes : `https://www.42evalhub.com/data/specs/Inception-of-Things.html`)

Légende : **[S]** = exigé par le sujet · **[E]** = vérifié par la fiche d'éval · **[⚠]** = piège ou point à trancher.

---

## 0. Règles générales

| # | Exigence | Source |
|---|----------|--------|
| G1 | Tout le projet est réalisé **dans une machine virtuelle** (pour la soutenance, la VM de 42). Il faut donc de la virtualisation imbriquée pour P1/P2 (VirtualBox/libvirt dans la VM). | [S][E] |
| G2 | Dossiers à la racine du repo : `p1`, `p2`, `p3`, plus `bonus` en option. | [S][E] |
| G3 | Dans chaque partie : `Vagrantfile` (P1, P2 et bonus), `scripts/` pour les scripts, `confs/` pour les fichiers de configuration. | [S] |
| G4 | Le choix de l'outil qui fait tourner la VM hôte et du provider Vagrant est libre. | [S] |
| G5 | La soutenance se fait sur la machine du groupe, à partir d'un `git clone` dans un dossier vide. Attention aux alias malveillants : seul le contenu du repo compte. | [S][E] |
| G6 | Le groupe doit savoir expliquer simplement le fonctionnement de **K3s**, de **Vagrant**, de **K3d**, ainsi que ce que sont la **CI** et **Argo CD**. | [E] |

Arborescence attendue :

```
.
├── p1/      Vagrantfile  scripts/  confs/
├── p2/      Vagrantfile  scripts/  confs/
├── p3/                   scripts/  confs/
└── bonus/   Vagrantfile  scripts/  confs/
```

---

## 1. Partie 1 : K3s et Vagrant

### Exigences

| # | Exigence | Source |
|---|----------|--------|
| P1.1 | Un `Vagrantfile` qui définit **2 VMs**, écrit selon les « modern practices ». | [S][E] |
| P1.2 | OS : **dernière version stable** de la distribution choisie, pour les deux VMs. | [S][E] |
| P1.3 | Ressources minimales fortement conseillées : **1 CPU, 512 Mo** (ou 1024 Mo) de RAM. | [S] |
| P1.4 | Noms et hostnames : `<login>S` pour le serveur et `<login>SW` pour le worker (ex. `wilS`, `wilSW`). | [S][E] |
| P1.5 | IP dédiée sur l'**interface réseau principale** : Server `192.168.56.110`, ServerWorker `192.168.56.111`. | [S][E] |
| P1.6 | Connexion SSH sans mot de passe sur les deux machines (`vagrant ssh <nom>`). | [S][E] |
| P1.7 | K3s en mode **controller (server)** sur `S` et en mode **agent** sur `SW`. | [S][E] |
| P1.8 | `kubectl` installé et utilisable. | [S] |
| P1.9 | Sur le Server, `kubectl get nodes -o wide` affiche les 2 nœuds `Ready` avec les bonnes INTERNAL-IP, et le groupe sait expliquer cette sortie. | [E] |

### Vérifications faites en soutenance

```bash
vagrant up && vagrant ssh <login>S                 # puis <login>SW
ip a show $(ip route | grep default | awk '{print $5}')   # doit montrer 192.168.56.11x
hostname                                         # <login>S / <login>SW
kubectl get nodes -o wide                        # 2 nœuds, même cluster
```

### Notes d'implémentation

- **Installation de K3s** avec le script officiel `curl -sfL https://get.k3s.io | sh -`, paramétré par des variables d'environnement :
  - Server : `INSTALL_K3S_EXEC="server --node-ip=192.168.56.110 --flannel-iface=<iface> --write-kubeconfig-mode=644"`
  - Agent : `K3S_URL=https://192.168.56.110:6443`, `K3S_TOKEN=<token>`, `INSTALL_K3S_EXEC="agent --node-ip=192.168.56.111 --flannel-iface=<iface>"`
  - **Choix retenu (P1)** : les options fixes (`write-kubeconfig-mode`, `disable`, URL du server) sont dans `p1/confs/server.yaml` et `agent.yaml`, installés en `/etc/rancher/k3s/config.yaml`. Seuls `--node-ip` et `--flannel-iface` restent dans `INSTALL_K3S_EXEC`.
- **Token** : il se trouve dans `/var/lib/rancher/k3s/server/node-token` sur le serveur. On le transmet au worker via le dossier synchronisé `/vagrant`, ou bien on fixe un token prédéfini (`K3S_TOKEN`) des deux côtés.
- **kubectl** : l'installeur K3s crée le lien `/usr/local/bin/kubectl -> k3s`, et le kubeconfig se trouve dans `/etc/rancher/k3s/k3s.yaml`.
- **[⚠] Mémoire** : la doc K3s demande **2 cœurs / 2 Go** pour un server (512 Mo pour un agent). Avec 1 CPU / 1024 Mo, le server sature (testé : 3 Mo disponibles, API en timeout). **Choix retenu** : garder 1024 Mo et désactiver dans P1 ce qui ne sert pas : `--disable=traefik,servicelb,metrics-server,local-storage --disable-helm-controller --disable-network-policy`. Résultat testé : environ 220 Mo disponibles sur le server. Ça ne vaut pas pour P2, qui a besoin de Traefik.
- **Ordre de démarrage** : le worker doit attendre que l'API du serveur réponde (boucle sur `:6443` ou sur la présence du token).
- **[⚠] Interface principale** : avec VirtualBox, Vagrant crée une interface NAT (`eth0`/`enp0s3`, `10.0.2.15`) qui porte la route par défaut, puis une interface host-only (`eth1`/`enp0s8`) pour `private_network`. La commande d'éval `ip a show $(ip route | grep default ...)` affiche l'interface qui porte la route par défaut, donc **le NAT et pas `192.168.56.11x`**. Il faut décider d'une stratégie et la tester :
  1. faire passer la route par défaut par l'interface `192.168.56.x` après le provisioning (attention, le host-only VirtualBox ne donne pas accès à Internet) ;
  2. utiliser un provider ou une configuration réseau où l'interface principale porte directement l'IP voulue ;
  3. a minima, savoir le justifier à l'oral (risque d'échec si le correcteur applique la fiche à la lettre).

  **Choix retenu : option 1.** `scripts/set-default-route.sh` (lancé avec `run: "always"`, donc à chaque `vagrant up`/`reload`) :
  - fait passer `default` par l'interface host-only, via `192.168.56.1` ;
  - ajoute `0.0.0.0/1` et `128.0.0.0/1` vers la passerelle NAT. Ces routes sont plus spécifiques que `default`, donc le trafic réel sort toujours par le NAT et Internet reste accessible.

  À l'oral : « la route `default` désigne l'interface principale, mais les deux `/1` couvrent tout l'espace IPv4 et gagnent par la règle du préfixe le plus long ».
- **[⚠] K3s choisit son IP par défaut** sur l'interface de la route par défaut (le NAT). Il faut donc **toujours** passer `--node-ip` et `--flannel-iface`, sinon les nœuds s'annoncent en `10.0.2.15` et le réseau entre pods est cassé.
- **[⚠] Noms d'interfaces** : sur les distributions récentes, on trouve `enp0s8` plutôt que `eth1`. Mieux vaut la détecter dynamiquement (par l'IP) que la coder en dur.
- **[⚠] VirtualBox ≥ 6.1.28** n'autorise par défaut que la plage `192.168.56.0/21` en host-only, ce qui convient à `192.168.56.110/111`.
- **Box** : choisir une box maintenue qui correspond à la dernière version stable (par ex. Debian 13 « trixie », sortie le 9 août 2025, ou la dernière Ubuntu LTS). Vérifier sur le catalogue Vagrant que la box existe pour le provider retenu.
- Le sujet montre `v.customize ["modifyvm", :id, "--name", "wilS"]`, c'est-à-dire le nom de la VM côté VirtualBox. Avec VirtualBox, on peut aussi utiliser `v.name`.

---

## 2. Partie 2 : K3s et trois applications simples

### Exigences

| # | Exigence | Source |
|---|----------|--------|
| P2.1 | Un `Vagrantfile` avec **une seule VM**, dernière version stable de la distribution, K3s en mode **server**. | [S][E] |
| P2.2 | Nom et hostname `<login>S`, IP `192.168.56.110` sur l'interface principale. | [S][E] |
| P2.3 | **3 applications web** au choix, qui tournent dans K3s. | [S][E] |
| P2.4 | Routage selon l'en-tête **HOST** vers `192.168.56.110` : `app1.com` → app1, `app2.com` → app2, tout autre host → **app3 (par défaut)**. | [S][E] |
| P2.5 | **app2 a 3 réplicas.** | [S] |
| P2.6 | `kubectl get all` montre les 3 applications (deployments, replicasets, pods, services). | [E] |
| P2.7 | Le groupe montre et explique son **Ingress** (la commande n'est volontairement pas donnée, c'est-à-dire `kubectl get ingress`, puis `kubectl describe ingress <nom>`). | [S][E] |
| P2.8 | Les fichiers en trop dans `p2/` doivent pouvoir être expliqués. | [E] |

### Vérifications faites en soutenance

```bash
kubectl get nodes -o wide
kubectl get all
kubectl get ingress && kubectl describe ingress <nom>
curl -H "Host: app1.com" http://192.168.56.110     # app1
curl -H "Host: app2.com" http://192.168.56.110     # app2 (servi par l'un des 3 réplicas)
curl http://192.168.56.110                          # app3 (défaut)
curl -H "Host: nimporte.quoi" http://192.168.56.110 # app3
```

### Notes d'implémentation

- K3s embarque **Traefik** comme Ingress Controller et **ServiceLB (klipper-lb)**, il n'y a rien à installer en plus.
- Manifests dans `p2/confs/` : 3 × (`Deployment` + `Service` ClusterIP) et 1 `Ingress` avec :
  - `rules[].host: app1.com` → service app1
  - `rules[].host: app2.com` → service app2
  - une règle **sans host** (ou `spec.defaultBackend`) → service app3
- Application simple : une image légère (par ex. `nginx`, `hashicorp/http-echo`, `paulbouwer/hello-kubernetes`) dont le contenu varie par app (ConfigMap montée, ou argument). L'idéal est que la réponse affiche le nom du pod, ce qui permet de **montrer les 3 réplicas** d'app2.
- Le provisioning applique les manifests (`kubectl apply -f /vagrant/confs/`) une fois que K3s est prêt (attendre le nœud `Ready` et les CRD Traefik).
- **Choix retenus** (testés sur le banc KVM) :
  - **image** : `traefik/whoami:v1.12.0` (environ 5 Mo). `WHOAMI_NAME` affiche `Name: appN`, et `Hostname:` donne le nom du pod, ce qui montre l'alternance entre les 3 réplicas d'app2 ;
  - **app3 par défaut** : une règle sans `host` dans l'Ingress, affichée `*` par `kubectl describe ingress apps` ;
  - **mémoire** : on garde Traefik, ServiceLB et le contrôleur Helm, qui déploie Traefik, et on désactive `metrics-server`, `local-storage` et le contrôleur de network policy. Mesure : 80 à 90 Mo disponibles sur 967 une fois tout démarré. C'est juste, mais stable.
  - **Traefik démarre environ 40 s après le provisioning**, car le chart Helm s'installe en tâche de fond. Pendant ce temps, `curl` ne répond pas.

---

## 3. Partie 3 : K3d et Argo CD (sans Vagrant)

### Exigences

| # | Exigence | Source |
|---|----------|--------|
| P3.1 | **Pas de Vagrant.** K3d est installé directement dans la VM (celle de 42 en soutenance). | [S] |
| P3.2 | Un **script** qui installe pendant la soutenance tous les paquets nécessaires : Docker, kubectl, k3d (et éventuellement le CLI argocd). | [S] |
| P3.3 | Savoir expliquer la **différence entre K3s et K3d**. | [S][E] |
| P3.4 | **2 namespaces** : `argocd` (Argo CD) et `dev` (l'application). | [S][E] |
| P3.5 | Au moins 1 pod dans `dev`, et le groupe sait expliquer la différence entre namespace et pod. | [E] |
| P3.6 | L'application dans `dev` est **déployée automatiquement par Argo CD** à partir d'un **repo GitHub public**. | [S][E] |
| P3.7 | Le **nom du repo GitHub contient le login** d'un membre (ex. `wil_config`, `wil-ception`). | [S][E] |
| P3.8 | L'application a **2 versions** taguées `v1` et `v2`. Soit `wil42/playground` (port **8888**), soit une image perso sur un **Docker Hub public** dont le nom de repo contient un login, avec les tags `v1` et `v2`. | [S][E] |
| P3.9 | Interface Argo CD accessible dans le navigateur, avec un login et un mot de passe fournis au correcteur. | [E] |
| P3.10 | Démo : `curl http://localhost:8888/` → `{"status":"ok", "message": "v1"}`, puis modification du tag dans le manifest sur GitHub (commit + push), synchronisation par Argo CD (automatique, sinon manuelle), puis `curl` → `v2`. | [S][E] |
| P3.11 | Docker Hub doit être effectivement utilisé (point éliminatoire en cas de doute). | [E] |

### Vérifications faites en soutenance

```bash
kubectl get ns                    # argocd, dev
kubectl get pods -n dev
kubectl get pods -n argocd
curl http://localhost:8888/       # v1
# éditer le tag de l'image sur GitHub v1 -> v2, puis commit + push
# Argo CD synchronise
curl http://localhost:8888/       # v2
```

### Notes d'implémentation

- **K3s et K3d** : K3s est une distribution Kubernetes légère qui s'installe sous forme de binaire et de service systemd sur une machine ou une VM. K3d est un wrapper qui fait tourner des nœuds **K3s dans des conteneurs Docker**, ce qui donne des clusters jetables qu'on crée en quelques secondes et qui ne demandent pas de VM.
- Création du cluster avec exposition des ports, par exemple :
  `k3d cluster create iot -p "8888:8888@loadbalancer"` (avec un Service `LoadBalancer` sur le port 8888), ou `kubectl port-forward`.
- Installation d'Argo CD :
  `kubectl create ns argocd && kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`
- Mot de passe admin initial :
  `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`
- Accès à l'interface : `kubectl port-forward svc/argocd-server -n argocd 8080:443`, ou bien un Ingress / un mapping de port k3d.
- Objet `Application` (CRD Argo CD) défini de façon déclarative dans `p3/confs/` :
  `source.repoURL` = repo GitHub public, `destination.namespace: dev`, `syncPolicy.automated: {prune: true, selfHeal: true}`, éventuellement `syncOptions: [CreateNamespace=true]`.
- **Deux repos** : le repo 42 (rendu) contient `p3/scripts` et `p3/confs` (cluster, Argo CD, Application). Le repo GitHub public `<login>-…` contient les manifests que surveille Argo CD (`deployment.yaml`, `service.yaml`).
- Par défaut, Argo CD interroge le repo **toutes les ~3 min** (`timeout.reconciliation`). En soutenance, on peut lancer un *Refresh* ou *Sync* manuel, ce que la fiche autorise explicitement.
- Le script d'installation doit être **idempotent** et fonctionner sur une VM vierge, puisque la soutenance se fait sur un clone neuf.

---

## 4. Bonus : GitLab local

Le bonus n'est évalué que si **toute** la partie obligatoire est parfaite.

| # | Exigence | Source |
|---|----------|--------|
| B.1 | Ajouter **GitLab** (dernière version officielle) au lab de la partie 3. | [S] |
| B.2 | Instance GitLab **locale**, dans un namespace dédié **`gitlab`**. | [S] |
| B.3 | GitLab est configuré pour fonctionner avec le cluster. | [S] |
| B.4 | Tout ce qui marche en P3 marche aussi avec le GitLab local : Argo CD suit un repo **hébergé sur ce GitLab**. | [S][E] |
| B.5 | Démo : créer un repo dans GitLab, y pousser du code, puis refaire la bascule v1 → v2 via GitLab et Argo CD. | [E] |
| B.6 | Dossier `bonus/` avec `Vagrantfile` (selon l'exemple), `scripts/` et `confs/`. | [S] |

### Notes d'implémentation

- Helm est autorisé et recommandé : chart officiel `gitlab/gitlab` (https://charts.gitlab.io).
- GitLab est **très gourmand** (prévoir au moins ~8 Go de RAM et plusieurs vCPU pour la VM). Partir de l'exemple « minimum » du chart et désactiver ce qui ne sert pas (cert-manager, runner, prometheus, registry si inutile).
- `repoURL` dans Argo CD : l'URL du service interne au cluster (par ex. `http://gitlab-webservice-default.gitlab.svc:8181/<groupe>/<repo>.git`), ou un host résolu par `/etc/hosts`.
- Mot de passe root initial : secret `gitlab-gitlab-initial-root-password` dans le namespace `gitlab`.

---

## 5. Définitions simples (à savoir dire à l'oral)

- **Vagrant** : un outil qui crée des machines virtuelles à partir d'un fichier texte, le `Vagrantfile`. On y décrit l'OS (la « box »), la RAM, le CPU, l'IP et les scripts d'installation, puis `vagrant up` construit les VMs à l'identique à chaque fois. Vagrant ne virtualise pas lui-même : il pilote un *provider* comme VirtualBox ou libvirt.
- **K3s** : une version allégée de Kubernetes, sous forme d'un seul binaire d'environ 70 Mo, conçue pour les petites machines. Elle s'installe en une commande, comme un service système. Un nœud **server** pilote le cluster (API, planification) et des nœuds **agent** exécutent les conteneurs. Traefik (Ingress), un load balancer et le réseau sont fournis d'office.
- **K3d** : un outil qui fait tourner K3s **dans des conteneurs Docker** au lieu de VMs ou de machines réelles. Chaque nœud du cluster est un conteneur, ce qui permet de créer ou détruire un cluster complet en quelques secondes avec `k3d cluster create`. En résumé, K3s est la distribution Kubernetes et K3d est la façon de la lancer dans Docker.
- **CI (Intégration Continue)** : une pratique où chaque modification de code poussée sur Git déclenche automatiquement un build et des tests, pour détecter les erreurs tôt. Son prolongement, le **CD** (Déploiement Continu), met automatiquement en production ce qui a été validé.
- **Argo CD** : un outil de déploiement continu pour Kubernetes qui applique le principe **GitOps**. On décrit dans un repo Git l'état voulu de l'application (image, version, réplicas). Argo CD surveille ce repo et, dès qu'il change, met le cluster à jour pour qu'il corresponde. Pour passer de la v1 à la v2, il suffit de modifier le tag dans Git et de pousser.

## 6. Préparation de l'oral (questions attendues)

- **Vagrant** : ce qu'est un Vagrantfile, les boxes, les providers, le provisioning, `private_network`, les dossiers synchronisés, les clés SSH insecure/générées.
- **K3s** : distribution Kubernetes allégée (binaire unique, SQLite/etcd embarqué, Traefik, ServiceLB, Flannel), rôles server/agent, token de jonction, port 6443.
- **K3d** : K3s dans Docker, cluster et nœuds sous forme de conteneurs, loadbalancer serverlb, mapping de ports.
- **Objets Kubernetes** : Pod, Deployment, ReplicaSet, Service, Ingress, Namespace (namespace = isolation logique ; pod = unité d'exécution).
- **Ingress** : routage L7 par host ou path et backend par défaut, Traefik comme controller.
- **CI/CD et GitOps** : CI = intégration et tests continus, CD = livraison et déploiement continus. Argo CD est un outil de **CD GitOps** : Git fait foi, et Argo CD réconcilie l'état du cluster avec ce qui est déclaré (pull model, sync, self-heal, prune).
- Savoir lire `kubectl get nodes -o wide` : colonnes ROLES, INTERNAL-IP, VERSION, CONTAINER-RUNTIME.
