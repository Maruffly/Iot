# Récap du projet IoT (session du 2026-10-15)

À relire avant de reprendre. Le détail technique pour l'oral est dans [`SOUTENANCE.md`](SOUTENANCE.md), les exigences dans [`SPECS.md`](SPECS.md).

---

## 1. Où on en est

| Partie | État | Testé sur le banc KVM | Testé sur la VM de 42 |
|---|---|---|---|
| P1 : K3s server + agent (Vagrant) | ✅ fait, B1 corrigé | ✅ `up`, `reload`, `provision`, clone neuf | ❌ |
| P2 : 3 apps + Ingress (Vagrant) | ✅ fait | ✅ | ❌ |
| P3 : K3d + Argo CD (sans Vagrant) | ✅ fait | ✅ VM Debian 13 vierge, démo v1 → v2 | ❌ |
| Bonus : GitLab local | ⏳ pas commencé | – | – |

**Repos GitHub**

- `github.com/Maruffly/Iot` : le rendu. Contient P1, P2, P3 et les docs (dernier commit `a02fdff`).
- `github.com/Maruffly/jmaruffy-iot` : les manifests surveillés par Argo CD. Il est sur `v1`, prêt pour la soutenance.
- Le compte `jbmaruffy-rcube` (clé SSH du poste) est collaborateur des deux repos.

---

## 2. À faire à la prochaine session

1. ~~Commit + push de `p3/` et `docs/`~~ : fait (`a02fdff`).
2. Installer `shellcheck` (`sudo dnf install ShellCheck`), puis `shellcheck p*/scripts/*.sh`.
3. Commencer le **bonus** (GitLab dans le namespace `gitlab`).
4. Avant l'éval : dérouler la checklist « Avant l'éval » de `SOUTENANCE.md` sur la **VM de 42** (VirtualBox, box `bento/debian-13`). Rien n'y a encore été testé.

---

## 3. Le sujet expliqué simplement (en partant de Docker)

### Machine virtuelle et conteneur

Un conteneur Docker est un processus isolé qui **partage le noyau Linux** de la machine : il démarre en une seconde et pèse peu.
Une **VM** est un **ordinateur entier simulé**, avec son noyau, son disque, sa RAM réservée et sa carte réseau. Un hyperviseur (VirtualBox à 42, KVM sur le poste) fait croire à l'OS invité qu'il tourne sur du vrai matériel.

| | Conteneur Docker | VM |
|---|---|---|
| Noyau | celui de l'hôte | le sien |
| Démarrage | ~1 s | ~30 s à 1 min |
| Poids | quelques Mo | quelques Go |
| Isolation | processus | machine complète |

### Vagrant, le docker-compose des VMs

| Docker | Vagrant |
|---|---|
| `docker-compose.yml` | `Vagrantfile` |
| `image: debian:13` | `config.vm.box = "bento/debian-13"` (une **box** est une image de VM) |
| `RUN` dans un Dockerfile | `provision "shell", path: "scripts/server.sh"` (script lancé dans la VM) |
| `networks:` | `private_network, ip: "192.168.56.110"` |
| `docker exec -it` | `vagrant ssh jmaruffyS` |
| `docker compose down` | `vagrant destroy -f` |

### Kubernetes

Docker lance des conteneurs sur **une** machine. Kubernetes les gère sur un **groupe de machines** (un cluster). On lui dit « je veux 3 copies de cette app » : il les place, les relance si elles tombent et répartit le trafic.

| Terme | Équivalent approximatif |
|---|---|
| **Node** | une machine du cluster |
| **Pod** | un conteneur (ou un petit groupe) en train de tourner |
| **Deployment** | « garde N pods de telle image en vie » |
| **Service** | une adresse fixe devant des pods qui changent (répartition de charge) |
| **Ingress** | un reverse proxy (comme nginx) qui route selon le nom de domaine |
| **Namespace** | un dossier logique pour ranger les objets |
| **Manifest** | un fichier YAML qui décrit un objet |
| **kubectl** | la commande pour parler au cluster (l'équivalent de `docker`) |

Le **server** (control plane) est le cerveau ; les **agents** (workers) exécutent les pods.
**K3s** est un Kubernetes allégé (un seul binaire), pensé pour les petites machines.

---

## 4. Les parties et ce qui a été implémenté

### Partie 1 : un cluster de 2 machines

**Sujet** : 2 VMs Vagrant, `jmaruffyS` (server, `192.168.56.110`) et `jmaruffySW` (agent, `.111`), avec 1 CPU et 1 Go. L'agent doit rejoindre le cluster.

**Implémentation** (`p1/`)
- `Vagrantfile` : les 2 VMs, le server défini en premier pour démarrer avant l'agent.
- `scripts/server.sh` : installe K3s en server, dépose le **token** (le mot de passe du cluster) dans le dossier partagé `/vagrant`.
- `scripts/agent.sh` : attend le token, puis installe K3s en agent.
- `scripts/set-default-route.sh` : met la route par défaut sur l'IP `192.168.56.x` (voir §5).
- `confs/server.yaml` / `confs/agent.yaml` : la configuration K3s, copiée en `/etc/rancher/k3s/config.yaml`.

**Vérification** : `kubectl get nodes -o wide` montre 2 nœuds `Ready`.

### Partie 2 : 3 sites derrière un seul point d'entrée

**Sujet** : une VM K3s, 3 apps. `app1.com` → app1, `app2.com` → app2 (**3 copies**), tout autre nom → app3.

**Implémentation** (`p2/`)
- `confs/app1.yaml`, `app2.yaml`, `app3.yaml` : un Deployment (image `traefik/whoami`) et un Service chacun ; app2 a `replicas: 3`.
- `confs/ingress.yaml` : règles de routage par en-tête `Host`, app3 par défaut. Appliquées par **Traefik**, fourni avec K3s.
- `scripts/server.sh` : installe K3s puis `kubectl apply -f confs/`.

**Démo** : `curl -H "Host: app2.com" http://192.168.56.110` plusieurs fois → un pod différent répond à chaque fois.

### Partie 3 : GitOps avec K3d et Argo CD

**Sujet** : pas de VM.
- **K3d** fait tourner K3s **dans des conteneurs Docker** (`docker ps` montre le cluster).
- **Argo CD** surveille un repo GitHub et applique tout seul les changements au cluster. C'est le **GitOps** : Git est la source de vérité.

**Démo attendue** : `curl localhost:8888` → `v1` ; on change le tag en `v2` sur GitHub (commit + push) ; Argo CD redéploie ; `curl` → `v2`.

**Implémentation**
- `p3/scripts/install.sh` : installe Docker (dépôt apt officiel), kubectl (dernière stable, vérifiée par sha256), k3d (script officiel) ; ajoute l'utilisateur au groupe `docker`.
- `p3/scripts/deploy.sh` : crée le cluster k3d `iot` (port 8888 exposé, Traefik et metrics-server désactivés), les namespaces, installe Argo CD, applique l'`Application`, attend l'app et affiche le mot de passe admin.
- `p3/confs/namespaces.yaml` : `argocd` et `dev`.
- `p3/confs/application.yaml` : « Argo CD, surveille `github.com/Maruffly/jmaruffy-iot` et déploie-le dans `dev` », en synchro automatique.
- Repo `jmaruffy-iot` : `deployment.yaml` (`wil42/playground:v1`, port 8888) et `service.yaml` (type LoadBalancer, port 8888).

**Ce qui se passe au lancement**

```
install.sh   →  installe Docker, kubectl, k3d
deploy.sh    →  k3d cluster create iot           (des conteneurs Docker deviennent un cluster K3s)
             →  kubectl apply namespaces.yaml    (argocd, dev)
             →  installe Argo CD dans argocd
             →  kubectl apply application.yaml   (« surveille jmaruffy-iot »)
Argo CD      →  lit deployment.yaml + service.yaml sur GitHub, crée le pod dans dev
k3d          →  relie le port 8888 de la machine au Service
curl localhost:8888  →  {"status":"ok", "message": "v1"}
```

**Commandes utiles en soutenance**

```bash
./p3/scripts/install.sh && ./p3/scripts/deploy.sh
kubectl get ns && kubectl get pods -n dev
curl http://localhost:8888/
kubectl port-forward svc/argocd-server -n argocd 8080:443   # puis https://localhost:8080, login admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

### Bonus (à faire)

Remplacer GitHub par un **GitLab hébergé dans le cluster** (namespace `gitlab`).

---

## 5. Les problèmes rencontrés et leurs solutions

**Deux cartes réseau par VM (P1, P2).** VirtualBox donne `eth0` (NAT, `10.0.2.15`, **identique dans toutes les VMs**, pour Internet) et `eth1` (réseau privé `192.168.56.x`).
- K3s prendrait `10.0.2.15` et les nœuds auraient la même IP → on force `--node-ip` et `--flannel-iface`, l'interface étant détectée d'après l'IP.
- La commande d'éval regarde l'interface de la route par défaut, donc afficherait `10.0.2.15` → `set-default-route.sh` déplace la route par défaut sur `eth1`, et deux routes `/1` plus précises gardent Internet sur le NAT (règle du préfixe le plus long). Relancé à chaque démarrage.

**Le token de l'agent (P1).** Généré par le server à l'installation, donc inconnu à l'avance. Passé par `/vagrant`, le dossier du projet partagé avec les VMs (comme un volume Docker monté dans deux conteneurs). Ignoré par Git.

**1 Go de RAM (P1).** K3s demande 2 Go pour un server. On désactive les composants inutiles en P1 (Traefik, métriques, stockage…) : il reste ~200 Mo libres.

**B1 : dossier vide (corrigé aujourd'hui).** Git ne versionne pas les dossiers vides : `p1/confs/` disparaissait au `git clone` et le script plantait. Les options K3s sont maintenant dans `confs/server.yaml` et `agent.yaml`, au format officiel de K3s.

**B2 : tester comme le correcteur (fait aujourd'hui).** Repo poussé sur `Maruffly/Iot`, cloné dans un dossier vide, `vagrant up` de P1 : le cluster démarre.

**P3 : disque lent sur le banc.** Le banc empile Windows → WSL2 → VM KVM → Docker → K3s → Argo CD. Le disque de la VM mettait ~45 ms par écriture synchrone ; la base de K3s ne suivait plus et Argo CD ne démarrait pas, même avec 4 vCPU. Contourné sur le banc seulement (cache disque `unsafe`). Si `deploy.sh` expire sur la VM de 42, mesurer :
`dd if=/dev/zero of=/var/tmp/t bs=4k count=300 oflag=dsync` (normalement < 1 s).
Prévoir au moins **2 vCPU et 4 Go** pour P3.

---

## 6. Banc de test local (rappel)

- Vagrant + libvirt/KVM dans WSL2, appelé avec `sg libvirt -c "VAGRANT_DEFAULT_PROVIDER=libvirt /usr/bin/vagrant …"`.
- Box `debian/trixie64` au lieu de `bento/debian-13` (pas de version libvirt), réglages dans `~/.vagrant.d/Vagrantfile`.
- Ce banc ne remplace pas le test final sur la VM de 42 avec VirtualBox.
