# Préparation de la soutenance : état du projet (P1, P2 et P3)

Point fait le 2026-10-14, P3 ajouté le 2026-10-15. Les exigences numérotées (P1.x, P2.x, P3.x) renvoient à [`SPECS.md`](SPECS.md).

> **Statut des tests.** P1 et P2 ont été testés de bout en bout sur un **banc local KVM/libvirt** (WSL2), avec la box `debian/trixie64`.
> Ils n'ont **pas encore** été testés avec VirtualBox et `bento/debian-13`, la configuration de la soutenance. Il faut repasser la checklist sur la VM de 42 avant l'éval.
> P3 a été testé sur une **VM Debian 13.5 vierge** du banc (2 vCPU, 4 Go) : `install.sh`, `deploy.sh`, puis démo v1 → v2 réussie.

---

## 0. À corriger avant tout

| # | Problème | Conséquence | Correction proposée |
|---|----------|-------------|---------------------|
| ~~B1~~ | ✅ **Corrigé le 2026-10-15.** `p1/confs/` était vide, donc absent après un `git clone` (le `cp` du token échouait). | – | Les options K3s sont dans `confs/server.yaml` et `confs/agent.yaml`, copiés en `/etc/rancher/k3s/config.yaml` (voir §1, point 8). |
| ~~B2~~ | ✅ **Fait le 2026-10-15.** Repo Git créé (remote `git@github.com:Maruffly/Iot.git`). | – | Clone neuf dans un dossier vide + `vagrant up` de P1 testé sur le banc : 2 nœuds `Ready`. |

---

## 1. Partie 1 : K3s et Vagrant

### Ce qui a été fait

```
p1/
├── Vagrantfile                 2 VMs, Debian 13, 1 CPU / 1024 Mo
├── scripts/
│   ├── set-default-route.sh    route par défaut sur 192.168.56.x (à chaque boot)
│   ├── server.sh               K3s server + partage du token
│   └── agent.sh                K3s agent, rejoint le server
└── confs/
    ├── server.yaml             config K3s du server (→ /etc/rancher/k3s/config.yaml)
    └── agent.yaml              config K3s de l'agent (URL du server)
```

**Déroulé de `vagrant up` :**
1. `jmaruffyS` démarre en premier : Vagrant démarre les machines dans l'ordre où elles sont définies.
2. `set-default-route.sh` fait de `192.168.56.110` l'interface principale.
3. `server.sh` copie `confs/server.yaml` en `/etc/rancher/k3s/config.yaml`, installe K3s en mode server, attend `/var/lib/rancher/k3s/server/node-token` et le copie dans `/vagrant/confs/node-token`. `/vagrant` est le dossier `p1/` de l'hôte, partagé avec les VMs.
4. `jmaruffySW` démarre, puis `set-default-route.sh` s'exécute.
5. `agent.sh` attend le token et la réponse de l'API sur `:6443`, copie `confs/agent.yaml` (qui contient l'URL du server), puis installe K3s en mode agent avec `K3S_TOKEN`.

### Correspondance avec le sujet

| Exigence | Où et comment | Vérifié sur le banc |
|---|---|---|
| P1.1 : 2 VMs, « modern practices » | Constantes regroupées en tête, `config.vm.define` par machine, `vb.name` à la place de `customize ["modifyvm"…]`, `linked_clone` | ✅ |
| P1.2 : dernière version stable | `bento/debian-13` (Debian 13 « trixie », stable depuis le 9 août 2025), `box_check_update = true` | ⚠ box non testée (banc sur `debian/trixie64`) |
| P1.3 : 1 CPU, 512 ou 1024 Mo | `vb.cpus = 1`, `vb.memory = 1024` | ✅ |
| P1.4 : noms `jmaruffyS` / `jmaruffySW` | `vm.hostname` (dans la VM) + `vb.name` (dans VirtualBox) | ✅ `hostname` |
| P1.5 : IP sur l'interface principale | `private_network` + `set-default-route.sh` | ✅ la commande d'éval affiche `eth1 192.168.56.11x` |
| P1.6 : SSH sans mot de passe | Fourni par Vagrant : clé générée par machine, `vagrant ssh <nom>` | ✅ |
| P1.7 : server sur S, agent sur SW | `server.sh` / `agent.sh` | ✅ |
| P1.8 : kubectl | Lien `kubectl → k3s` créé par l'installeur, `--write-kubeconfig-mode=644` pour l'utiliser sans sudo | ✅ |
| P1.9 : `kubectl get nodes -o wide` | 2 nœuds `Ready`, INTERNAL-IP `.110` / `.111` | ✅ |

Résultat obtenu sur le banc :

```
NAME         STATUS   ROLES           VERSION        INTERNAL-IP      OS-IMAGE
jmaruffys    Ready    control-plane   v1.36.5+k3s1   192.168.56.110   Debian GNU/Linux 13 (trixie)
jmaruffysw   Ready    <none>          v1.36.5+k3s1   192.168.56.111   Debian GNU/Linux 13 (trixie)
```

### Particularités à savoir défendre

**1. La route par défaut (le point le plus probable à l'oral).**
VirtualBox donne à chaque VM une interface NAT (`eth0`, `10.0.2.15`) qui porte la route `default`, puis l'interface host-only (`eth1`, `192.168.56.x`). La commande d'éval `ip a show $(ip route | grep default | awk '{print $5}')` afficherait donc `10.0.2.15`. `set-default-route.sh` :
- déplace `default` vers `eth1` (passerelle `192.168.56.1`, c'est-à-dire l'hôte) ;
- ajoute `0.0.0.0/1` et `128.0.0.0/1` vers la passerelle NAT. À elles deux, ces routes couvrent tout l'espace IPv4 et sont **plus spécifiques** (préfixe /1 contre /0). Par la règle du **préfixe le plus long**, le trafic réel sort par le NAT, alors qu'Internet n'est pas joignable via le réseau host-only.

> Phrase pour l'oral : « `default` désigne l'interface principale, mais les deux /1 gagnent par la règle du préfixe le plus long, donc Internet passe toujours par le NAT. »

- `run: "always"` est nécessaire parce que les routes ajoutées avec `ip route` ne survivent pas à un redémarrage. Le provisioner est rejoué à chaque `vagrant up` et `vagrant reload` (testé).
- `ip route replace` ajoute ou met à jour la route, donc le script est idempotent.

**2. `--node-ip` et `--flannel-iface`.** Sans eux, K3s annonce l'IP de l'interface NAT `10.0.2.15`, qui est identique sur les deux VMs, et le réseau entre pods (flannel/VXLAN) ne fonctionne plus. Le nom d'interface est **détecté à partir de l'IP** (`ip -o -4 addr show | awk …`) et pas codé en dur : selon la box, on obtient `eth1` ou `enp0s8`.

**3. Le token.** Le worker a besoin du secret du server pour rejoindre le cluster. Il passe par `/vagrant`, le dossier partagé entre l'hôte et les VMs, et il est ignoré par Git (`.gitignore`), donc aucun secret n'est commité.
- Alternative possible : un `K3S_TOKEN` fixé à l'avance des deux côtés. C'est plus simple, mais c'est un secret écrit en clair dans le repo.

**4. La mémoire (choix assumé).** La doc K3s indique un **minimum de 2 cœurs et 2 Go pour un server**, et 512 Mo pour un agent. Avec 1024 Mo et tous les composants, le server saturait : 3 Mo libres, API en timeout, `kubectl` inutilisable. P1 n'a besoin que d'un cluster de 2 nœuds, donc on désactive ce qui ne sert pas (clés de `confs/server.yaml`) :

| Option | Rôle du composant désactivé |
|---|---|
| `--disable=traefik` | Ingress controller (servira en P2) |
| `--disable=servicelb` | Implémente les Services `LoadBalancer` |
| `--disable=metrics-server` | Métriques CPU/RAM (`kubectl top`) |
| `--disable=local-storage` | Volumes persistants locaux |
| `--disable-helm-controller` | Déploie les charts Helm, ne sert qu'à installer Traefik |
| `--disable-network-policy` | Applique les `NetworkPolicy` |

Après ces désactivations, il reste environ 220 Mo libres sur le server. On garde **CoreDNS**, qui fait le DNS interne du cluster.

**5. Les noms de nœuds en minuscules.** Le hostname est `jmaruffyS`, mais le nœud s'appelle `jmaruffys`. Kubernetes impose des noms en minuscules (RFC 1123) et K3s les convertit, comme `wils` dans l'exemple du sujet.

**6. Idempotence.** `vagrant provision` peut être rejoué sans rien casser :
- `command -v k3s` saute l'installation si K3s est déjà là ;
- `ip route replace` ne fait rien si la route existe ;
- `cp` écrase le token avec la même valeur, `install` recopie la même config.

Limite : si on change une option K3s, il faut `vagrant destroy` puis `vagrant up` pour qu'il soit pris en compte.

**7. `curl` installé au besoin.** Une box minimale peut ne pas l'avoir. Le script ne suppose rien de la box et utilise `DEBIAN_FRONTEND=noninteractive`, sans prompt.

**8. Fichier de config K3s plutôt que flags.** K3s lit `/etc/rancher/k3s/config.yaml` à chaque démarrage : mêmes clés que les flags, sans `--`, et les flags répétables deviennent des listes YAML. Le partage se fait ainsi :
- **`confs/*.yaml`** : ce qui est fixe et lisible (options du server, URL du server pour l'agent) ;
- **ligne de commande** (`INSTALL_K3S_EXEC`) : `--node-ip` et `--flannel-iface`, propres à chaque VM, dont l'interface est détectée au provisioning. Si une clé est aux deux endroits, la ligne de commande l'emporte ;
- **`K3S_TOKEN`** : passé en variable d'environnement, donc jamais dans `confs/`. L'installeur le sauve dans `/etc/systemd/system/k3s-agent.service.env` pour les redémarrages.
- Sans `K3S_URL`, l'installeur choisit le mode d'après le premier mot de `INSTALL_K3S_EXEC` (`agent`).

---

## 2. Partie 2 : K3s et trois applications

### Ce qui a été fait

```
p2/
├── Vagrantfile                 1 VM jmaruffyS, 192.168.56.110
├── scripts/
│   ├── set-default-route.sh    copie de P1 (chaque partie est autonome)
│   └── server.sh               K3s server + kubectl apply -f /vagrant/confs
└── confs/
    ├── app1.yaml               Deployment (1 réplica) + Service
    ├── app2.yaml               Deployment (3 réplicas) + Service
    ├── app3.yaml               Deployment (1 réplica) + Service
    └── ingress.yaml            routage par Host
```

### Correspondance avec le sujet

| Exigence | Où et comment | Vérifié sur le banc |
|---|---|---|
| P2.1 : 1 VM, K3s server | `p2/Vagrantfile`, `server.sh` | ✅ |
| P2.2 : `jmaruffyS`, `192.168.56.110` | Même mécanique qu'en P1 | ✅ |
| P2.3 : 3 applications web | `traefik/whoami:v1.12.0` × 3, avec `WHOAMI_NAME=appN` | ✅ |
| P2.4 : routage par Host, app3 par défaut | `ingress.yaml` : `app1.com`, `app2.com`, règle **sans host** → app3 | ✅ |
| P2.5 : app2 a 3 réplicas | `replicas: 3` | ✅ 3 pods différents répondent tour à tour |
| P2.6 : `kubectl get all` | 3 deployments, 3 replicasets, 5 pods, 3 services | ✅ |
| P2.7 : montrer l'Ingress | `kubectl get ingress`, `kubectl describe ingress apps` | ✅ |
| P2.8 : pas de fichier en trop | Uniquement le nécessaire | ✅ |

Résultats obtenus avec `curl` depuis l'hôte :

```
Host: app1.com       → Name: app1  Hostname: app1-…-j55d2
Host: app2.com  ×3   → Name: app2  Hostname: …-hbtbx, …-xfpg2, …-qzkkp   (3 pods distincts)
(sans Host)          → Name: app3
Host: nimporte.quoi  → Name: app3
```

### Particularités à savoir défendre

**1. Le chemin d'une requête** (à savoir dessiner) :

```
curl -H "Host: app2.com" 192.168.56.110:80
  → svclb-traefik (ServiceLB : pod qui écoute sur le port 80 du nœud)
  → Service traefik (LoadBalancer)
  → pod Traefik : lit l'en-tête Host, trouve la règle app2.com dans l'Ingress
  → Service app2 (ClusterIP, IP virtuelle stable)
  → l'un des 3 pods app2 (répartition de charge)
```

**2. Les objets Kubernetes utilisés :**
- **Pod** : un ou plusieurs conteneurs, éphémère, avec une IP qui change.
- **Deployment** : décrit l'état voulu (image, nombre de réplicas). Il crée un **ReplicaSet**, qui maintient le bon nombre de pods. Si on supprime un pod, il est recréé.
- **Service ClusterIP** : une IP et un nom DNS stables devant un groupe de pods, choisis par `selector: app: appN`. Il répartit la charge entre eux.
- **Ingress** : des règles HTTP (host, chemin) vers des Services. C'est l'**Ingress controller**, ici Traefik, qui les applique.

**3. app3 par défaut.** La troisième règle de l'Ingress n'a pas de `host` : elle attrape toutes les requêtes que `app1.com` et `app2.com` n'ont pas prises. `kubectl describe` l'affiche avec `*`.

**4. Pourquoi `traefik/whoami`.**
- L'image est minuscule (environ 5 Mo), ce qui compte avec 1024 Mo de RAM.
- Elle affiche `Name:` (le nom de l'app) et `Hostname:`, c'est-à-dire le nom du pod, ce qui permet de **prouver les 3 réplicas** en direct.
- La version est fixée (`v1.12.0`, pas `latest`), donc reproductible.

**5. La mémoire.** Ici, on doit **garder** Traefik, ServiceLB et le contrôleur Helm, qui déploie Traefik. On ne désactive que `metrics-server`, `local-storage` et le contrôleur de network policy. Il reste 80 à 90 Mo libres : c'est juste, mais stable.

**6. Traefik met environ 40 s à démarrer.** Il est installé par un chart Helm en tâche de fond (les pods `helm-install-traefik*` passent à `Completed`). Pendant ce temps, `curl` ne renvoie rien. Pour la démo, attendre que `kubectl -n kube-system get pods` montre `traefik` en `Running`.

**7. Idempotence.** `kubectl apply` crée ou met à jour les objets. Un deuxième `vagrant provision` affiche `unchanged` partout (testé).

---

## 3. Partie 3 : K3d et Argo CD

### Ce qui a été fait

```
p3/
├── scripts/
│   ├── install.sh        Docker (dépôt apt officiel), kubectl (stable.txt + sha256), k3d (script officiel)
│   └── deploy.sh         cluster k3d "iot", namespaces, Argo CD, Application, attente de l'app
└── confs/
    ├── namespaces.yaml   argocd + dev
    └── application.yaml  Application Argo CD → github.com/Maruffly/jmaruffy-iot, namespace dev

github.com/Maruffly/jmaruffy-iot   (repo public séparé, surveillé par Argo CD)
├── deployment.yaml       wil42/playground:v1, port 8888
└── service.yaml          type LoadBalancer, port 8888
```

**Déroulé :**
1. `./p3/scripts/install.sh` installe les outils (avec `sudo`) et ajoute l'utilisateur au groupe `docker`.
2. `./p3/scripts/deploy.sh` :
   - se relance avec `sg docker` si le groupe `docker` n'est pas encore actif dans la session (évite de se déconnecter) ;
   - `k3d cluster create iot -p "8888:8888@loadbalancer" --k3s-arg "--disable=traefik,metrics-server@server:0"` ;
   - applique `namespaces.yaml`, installe Argo CD (`--server-side`), attend ses composants ;
   - applique `application.yaml`, attend que `curl localhost:8888` réponde, affiche le mot de passe admin.
3. Argo CD clone le repo `jmaruffy-iot` et crée le Deployment et le Service dans `dev`.

**Chemin d'une requête `curl localhost:8888`** : port 8888 de la VM → conteneur `k3d-iot-serverlb` (le load balancer de k3d, mappé par `-p`) → port 8888 du nœud `k3d-iot-server-0` (ouvert par ServiceLB de K3s car le Service est de type `LoadBalancer`) → pod `playground`.

### Résultats sur le banc

| Étape | Résultat |
|---|---|
| `install.sh` (×2) | Docker 29.9.1, kubectl v1.37.1, k3d v5.9.0 (K3s v1.35.5). Relance : OK |
| `deploy.sh` | ~5 min sur VM vierge (téléchargement des images compris), puis `{"status":"ok", "message": "v1"}` |
| Démo | push `v1` → `v2` sur GitHub, `v2` servi **~5 min** après (polling Argo CD ~3 min + pull de l'image). App `Synced` / `Healthy` |
| `deploy.sh` relancé | OK, rien de recréé |

### Particularités à savoir défendre

**1. K3s ou K3d ?** K3s est la distribution Kubernetes, installée comme service sur une machine (P1, P2). K3d est un outil qui lance des nœuds K3s **dans des conteneurs Docker** : `docker ps` montre `k3d-iot-server-0` et `k3d-iot-serverlb`. Création et destruction en quelques secondes, sans VM.

**2. GitOps.** L'état voulu du cluster est dans Git. Argo CD compare Git et le cluster, et corrige l'écart :
- `automated` : synchronise sans clic ;
- `prune: true` : supprime du cluster ce qui a été retiré du repo ;
- `selfHeal: true` : annule une modification faite à la main avec `kubectl`.
Pour la démo, cliquer *Refresh* dans l'interface évite d'attendre le polling (~3 min).

**3. Pourquoi deux repos ?** Le repo du rendu contient l'infrastructure (scripts, Application). Le repo `jmaruffy-iot` ne contient que ce qu'Argo CD déploie. Le sujet impose ce repo public avec le login dans le nom.

**4. Pas de `namespace:` dans les manifests de `jmaruffy-iot`.** Argo CD place les objets dans `destination.namespace` (`dev`) de l'Application.

**5. `--server-side` pour Argo CD.** Certaines CRD d'Argo CD sont trop grosses pour l'annotation qu'écrit un `kubectl apply` classique. C'est la commande de la doc officielle.

**6. Ressources.** K3s et les 7 composants d'Argo CD : environ 1,7 Go de RAM utilisés. Prévoir **au moins 2 vCPU et 4 Go** pour la VM de soutenance.

**7. Le disque lent (vécu sur le banc).** Sur le banc WSL2, chaque écriture synchrone prenait ~45 ms. La base SQLite de K3s (kine) ne suivait plus (`Slow SQL`), l'API ne répondait plus et Argo CD restait non-Ready, même avec 4 vCPU. Contourné sur le banc avec le cache disque `unsafe`. Sur la VM de 42, si `deploy.sh` expire, mesurer : `dd if=/dev/zero of=/var/tmp/t bs=4k count=300 oflag=dsync`.

**8. Version de kubectl.** kubectl v1.37 contre K3s v1.35 dans k3d : deux versions mineures d'écart, alors que Kubernetes garantit ±1. Aucun problème constaté pour les commandes de l'éval.

---

## 4. Pièges de la soutenance (P1 et P2)

| Piège | Parade |
|---|---|
| Le correcteur fait un `git clone` dans un dossier vide | Corriger B1 et B2, puis tester soi-même un clone neuf avant l'éval. |
| `ip a show $(ip route | grep default …)` affiche `10.0.2.15` | Déjà traité par `set-default-route.sh`. Savoir l'expliquer (§1, point 1). |
| La route `default` revient sur le NAT au renouvellement DHCP | **Non testé.** Si c'est le cas, `vagrant reload` la remet en place. Savoir l'expliquer. |
| « Pourquoi ne pas utiliser `latest` ou figer la version de K3s ? » | L'installeur prend la version stable du moment (le sujet demande la dernière version stable). Inconvénient : la version de K3s peut changer d'une soutenance à l'autre. On peut la figer avec `INSTALL_K3S_VERSION`. |
| « `curl … \| sh`, c'est sûr ? » | C'est la méthode officielle de K3s, en HTTPS, avec `-f` qui fait échouer le script en cas d'erreur HTTP. Dans un vrai contexte de production, on vérifierait le script ou on passerait par un paquet signé. |
| VMs de P1 encore actives au lancement de P2 | Les deux parties utilisent `192.168.56.110` : faire `vagrant destroy -f` dans `p1/` avant `vagrant up` dans `p2/`. |
| `kubectl get all` ne montre pas l'Ingress | C'est normal : `all` n'inclut pas les Ingress. Utiliser `kubectl get ingress`. |
| Ressources « 1 CPU / 512 Mo » | On a 1024 Mo, l'alternative autorisée par le sujet. Savoir citer le minimum de 2 Go de la doc K3s et expliquer les `--disable`. |
| Fichiers en trop | `node-token` est généré et ignoré par Git. Les dossiers `.vagrant/` sont aussi ignorés. |

---

## 5. Questions d'oral probables (réponses courtes)

- **K3s ?** Kubernetes allégé : un seul binaire, base SQLite par défaut, Traefik, ServiceLB, CoreDNS et flannel inclus.
- **Server ou agent ?** Le server porte le plan de contrôle (API, scheduler, stockage de l'état du cluster). L'agent exécute les pods (kubelet et containerd).
- **Vagrant ?** Décrit des VMs dans un fichier (`Vagrantfile`) et les crée avec un provider (VirtualBox). On obtient le même environnement à chaque fois.
- **Vagrant ou Docker ?** Vagrant crée une VM complète, avec son propre noyau. Un conteneur Docker partage le noyau de l'hôte. P3 (K3d) fait tourner K3s dans des conteneurs.
- **Pourquoi 3 réplicas ?** Pour la haute disponibilité et la répartition de charge : si un pod tombe, les deux autres répondent et le ReplicaSet en recrée un.
- **Namespace ou pod ?** Un namespace est un espace de noms logique qui regroupe des objets. Un pod est l'unité d'exécution qui contient les conteneurs.

---

## 6. Avant l'éval : checklist sur la VM de 42 (VirtualBox)

- [x] Corriger B1, `git init`, commit, puis `git clone` dans un dossier vide (banc KVM, à refaire sur la VM de 42)
- [ ] P1 : `vagrant up`, puis dans les deux VMs `hostname`, la commande `ip a show $(ip route | grep default …)` et `kubectl get nodes -o wide`
- [ ] P1 : `vagrant reload`, puis vérifier à nouveau la route
- [ ] P1 : `vagrant destroy -f`
- [ ] P2 : `vagrant up`, attendre Traefik, puis `kubectl get all`, `kubectl get ingress`, `kubectl describe ingress apps`
- [ ] P2 : les 4 `curl` (app1, app2 ×3, sans Host, autre Host) depuis l'hôte
- [ ] Mesurer la RAM (`free -m`) avec la box `bento/debian-13`
- [ ] P3 : `install.sh` puis `deploy.sh` sur la VM (au moins 2 vCPU / 4 Go), vérifier que `jmaruffy-iot` est sur `v1`
- [ ] P3 : `kubectl get ns`, `kubectl get pods -n dev`, `curl localhost:8888` → v1
- [ ] P3 : interface Argo CD (`port-forward` 8080:443), login `admin`
- [ ] P3 : push `v2` sur `jmaruffy-iot`, *Refresh*, `curl` → v2 ; puis remettre `v1`
- [ ] `shellcheck p*/scripts/*.sh`
