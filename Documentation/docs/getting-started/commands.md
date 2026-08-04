# Commandes disponibles

Le projet utilise un `Makefile` situé à la racine du dépôt pour regrouper les opérations courantes.

Les commandes doivent être exécutées depuis :

```text
machina-sandbox-full/
```

## Afficher l’aide

Pour afficher les commandes principales accompagnées de leur description :

```bash
make help
```

La liste est générée automatiquement à partir des commentaires présents dans le `Makefile`.

!!! note "Toutes les cibles ne sont pas affichichées"

    Certaines cibles internes, comme `ensure-local` ou `docs-ensure`, ne sont pas destinées à être exécutées directement et n’apparaissent pas dans l’aide.

## Identifier le bon terminal

Le projet distingue deux environnements d’exécution.

| Environnement | Description                                                                |
| ------------- | -------------------------------------------------------------------------- |
| Hôte Linux    | Terminal normal de la machine, en dehors du Dev Container                  |
| Dev Container | Terminal Visual Studio Code ouvert dans `/workspaces/machina-sandbox-full` |

Certaines commandes peuvent être exécutées dans les deux environnements, mais les commandes qui administrent directement Minikube sont généralement réservées à l’hôte.

!!! warning "Protection des commandes hôte"

    Plusieurs cibles utilisent une vérification interne appelée `ensure-local`.

    Si elles sont lancées depuis le Dev Container, elles s’arrêtent avec un message demandant de revenir dans le terminal Linux hôte.

## Commandes générales

### `make help`

Affiche la liste des commandes documentées dans le Makefile.

```bash
make help
```

### `make versions`

Affiche la version des principaux outils disponibles :

- Git ;
- Docker ;
- `kubectl` ;
- Helm ;
- Minikube ;
- Python ;
- Node.js ;
- npm.

```bash
make versions
```

Cette commande peut être utilisée dans le Dev Container ou sur l’hôte, mais la liste dépend des outils installés dans l’environnement courant.

### `make permissions`

Rend exécutables les scripts Bash présents dans :

```text
Application/scripts/
```

```bash
make permissions
```

!!! warning "Portée de la commande"

    Cette cible modifie les permissions des scripts avec `chmod +x`.

    Elle ne doit être utilisée que si les scripts ont perdu leur droit d’exécution.

## Cycle de vie Minikube sur l’hôte

Les commandes `host-*` utilisent l’outil :

```text
tools/host/machina-host
```

Elles sont conçues pour administrer le profil Minikube utilisé par le projet.

Elles doivent être exécutées dans le terminal Linux hôte.

### `make host-check`

Vérifie :

- le système Linux ;
- Docker ;
- Minikube ;
- le profil Kubernetes ;
- l’état du cluster.

```bash
make host-check
```

### `make host-bootstrap`

Prépare l’environnement Minikube.

Selon l’état de la machine, cette commande peut :

- installer Minikube dans `~/.local/bin/` ;
- créer le profil du projet ;
- démarrer le cluster ;
- mettre à jour le contexte Kubernetes.

```bash
make host-bootstrap
```

Cette commande est adaptée à la première installation.

### `make host-start`

Démarre le profil Minikube ou le crée si l’outil hôte le prévoit.

```bash
make host-start
```

### `make host-status`

Affiche l’état du profil Minikube.

```bash
make host-status
```

### `make host-stop`

Arrête le cluster sans supprimer son profil ni ses ressources persistantes.

```bash
make host-stop
```

### `make host-delete`

Supprime le profil Minikube après confirmation.

```bash
make host-delete
```

!!! danger "Suppression du cluster"

    Cette commande détruit les ressources présentes dans le cluster Minikube.

    Pour un arrêt temporaire, utiliser `make host-stop`.

## Connexion Kubernetes depuis le Dev Container

Ces commandes doivent être lancées dans le Dev Container.

### `make k8s-connect`

Connecte le Dev Container au réseau Docker du cluster Minikube et prépare le contexte Kubernetes.

```bash
make k8s-connect
```

La cible utilise le script :

```text
.devcontainer/connect-minikube.sh
```

### `make k8s-status`

Connecte le Dev Container puis affiche :

- le contexte Kubernetes ;
- les nœuds ;
- les pods de tous les namespaces ;
- les releases Helm.

```bash
make k8s-status
```

Cette commande dépend automatiquement de `make k8s-connect`.

## Validation Kubernetes et Helm

### `make validate-k8s`

Valide le déploiement Kubernetes sans installer l’application.

```bash
make validate-k8s
```

La cible réalise successivement :

1. `helm lint` sur le chart ;
2. `helm template` pour générer les manifests ;
3. kubeconform pour vérifier les ressources générées.

Le chart utilisé par défaut est :

```text
Application/machina-sandbox/
```

Le manifeste temporaire est généré dans :

```text
/tmp/machina-rendered.yaml
```

!!! info "Validation hors ligne"

    Cette commande valide le chart et les ressources générées sans nécessiter le déploiement de la release dans Kubernetes.

## Déploiement depuis le Dev Container

### `make devcont-bootstrap`

Effectue la première installation complète.

```bash
make devcont-bootstrap
```

Cette cible appelle actuellement :

```text
make devcont-deploy
```

### `make devcont-build-images`

Construit les images Docker nécessaires au déploiement Kubernetes :

- `fleet-api:latest` ;
- `front:latest` ;
- `eclipse-mosquitto:2`.

```bash
make devcont-build-images
```

Elle ne déploie pas l’application.

### `make devcont-load-images`

Connecte le Dev Container au cluster puis charge les images dans le conteneur Minikube.

```bash
make devcont-load-images
```

Les images sont transférées avec `docker save`, puis chargées dans le runtime Docker du nœud Minikube.

!!! warning "Images requises"

    Les images applicatives doivent déjà avoir été construites.

    Utiliser normalement :

    ```bash
    make devcont-build-images
    make devcont-load-images
    ```

    ou directement :

    ```bash
    make devcont-deploy
    ```

### `make devcont-deploy`

Réalise le cycle complet de déploiement :

1. validation Kubernetes ;
2. construction des images ;
3. chargement des images dans Minikube ;
4. installation ou mise à jour de la release Helm ;
5. redémarrage des déploiements ;
6. vérification de l’application.

```bash
make devcont-deploy
```

La release utilisée par défaut est :

```text
machina-sandbox
```

Le namespace utilisé par défaut est :

```text
machina-sandbox
```

### `make devcont-check`

Vérifie le déploiement courant.

```bash
make devcont-check
```

La commande contrôle notamment :

- la release Helm ;
- le broker ;
- Fleet API ;
- le frontend ;
- l’endpoint `/ready` de Fleet API ;
- l’accès HTTP au frontend ;
- l’accès au port MQTT WebSocket.

### `make devcont-status`

Affiche :

- la release Helm ;
- les déploiements ;
- les pods ;
- les services ;
- les URL calculées avec l’adresse IP actuelle de Minikube.

```bash
make devcont-status
```

Cette commande est préférable à l’utilisation d’une adresse IP Minikube enregistrée manuellement.

### `make devcont-start`

Redémarre une application déjà installée sans reconstruire les images.

```bash
make devcont-start
```

La commande remet les déploiements à une réplique et les démarre dans l’ordre suivant :

1. broker ;
2. Fleet API ;
3. frontend.

!!! warning "Première installation"

    Cette commande nécessite une release Helm existante.

    Pour une première installation, utiliser :

    ```bash
    make devcont-bootstrap
    ```

### `make devcont-stop`

Arrête les services applicatifs en réduisant leurs déploiements à zéro réplique.

```bash
make devcont-stop
```

La commande ne supprime pas :

- la release Helm ;
- le namespace ;
- le cluster Minikube.

## Docker Compose

Les commandes Compose utilisent :

```text
Application/docker-compose.yml
```

Le répertoire de projet Compose est :

```text
Application/
```

Les variables locales sont chargées depuis :

```text
Application/.env
```

### `make compose-config`

Valide la configuration Compose sans démarrer de conteneur.

```bash
make compose-config
```

La sortie affiche également les ports réellement utilisés.

### `make compose-up`

Valide la configuration, construit les images et démarre les services en arrière-plan.

```bash
make compose-up
```

Services actuellement déclarés :

- `broker` ;
- `fleet-api` ;
- `front`.

### `make compose-status`

Affiche l’état des services et leurs ports.

```bash
make compose-status
```

### `make compose-logs`

Affiche les 100 dernières lignes de logs et suit les nouveaux messages.

```bash
make compose-logs
```

Pour quitter le suivi :

```text
Ctrl+C
```

Les conteneurs continuent de fonctionner.

### `make compose-restart`

Redémarre les conteneurs existants sans reconstruire les images.

```bash
make compose-restart
```

### `make compose-down`

Arrête et supprime les conteneurs et le réseau Compose.

```bash
make compose-down
```

Les données stockées dans les dossiers liés au dépôt ne sont pas supprimées automatiquement.

## Installation du Dev Container

### `make dev-install`

Exécute le script de préparation du Dev Container :

```text
.devcontainer/post-create.sh
```

```bash
make dev-install
```

Cette commande prépare :

- les dépendances Python de Fleet API ;
- les dépendances Python du simulateur ;
- les dépendances npm du frontend ;
- les répertoires Kubernetes.

Elle est exécutée automatiquement lors de la création du Dev Container grâce à :

```text
postCreateCommand
```

Il n’est normalement pas nécessaire de la relancer à chaque ouverture.

## Documentation MkDocs

Les dépendances de la documentation sont isolées dans :

```text
Documentation/.venv/
```

### `make docs-install`

Crée l’environnement virtuel documentaire et installe les dépendances déclarées dans :

```text
Documentation/requirements-docs.txt
```

```bash
make docs-install
```

Cette commande vérifie ensuite les dépendances avec `pip check`.

### `make docs-check`

Construit la documentation en mode strict.

```bash
make docs-check
```

La construction échoue si MkDocs rencontre un avertissement considéré comme bloquant.

Cette commande est recommandée avant chaque commit documentaire.

### `make docs-build`

Génère le site statique dans :

```text
Documentation/site/
```

```bash
make docs-build
```

Le dossier généré est ignoré par Git.

### `make docs-serve`

Démarre le serveur de développement MkDocs.

```bash
make docs-serve
```

L’adresse par défaut est :

```text
http://localhost:8001
```

Le serveur reste actif au premier plan et recharge automatiquement les pages modifiées.

Pour l’arrêter :

```text
Ctrl+C
```

### `make docs-clean`

Supprime uniquement le site statique généré.

```bash
make docs-clean
```

Cette commande ne supprime ni les sources Markdown ni l’environnement virtuel documentaire.

## Monitoring et outils expérimentaux

Les commandes suivantes utilisent les scripts présents dans :

```text
Application/scripts/
```

Leur présence dans le Makefile ne garantit pas que tous les composants de monitoring soient installés dans le cluster courant.

### `make check-monitoring`

Vérifie Grafana, Prometheus, Loki et les releases Helm associées.

```bash
make check-monitoring
```

### `make check-prometheus`

Vérifie Prometheus et son endpoint de disponibilité.

```bash
make check-prometheus
```

### `make check-loki`

Vérifie Loki et son endpoint de disponibilité.

```bash
make check-loki
```

### `make check-argocd`

Vérifie Argo CD.

```bash
make check-argocd
```

### `make open-grafana`

Ouvre un port-forward vers Grafana sur :

```text
http://localhost:3000
```

```bash
make open-grafana
```

### `make open-argocd`

Ouvre un port-forward vers Argo CD.

```bash
make open-argocd
```

Le port par défaut est `8081`.

Il peut être surchargé :

```bash
make open-argocd ARGOCD_PORT=8090
```

!!! warning "État expérimental"

    Ces commandes appartiennent à la partie monitoring et GitOps historique du dépôt.

    Il faut vérifier les scripts et les composants réellement installés avant de les considérer comme opérationnels.

## Commandes hôte historiques

Le Makefile contient également un premier ensemble de commandes liées à Minikube et aux scripts d’exploitation.

Elles utilisent la protection `ensure-local` et doivent donc être lancées depuis l’hôte.

### `make restart`

Exécute :

```text
Application/scripts/restart-project.sh
```

```bash
make restart
```

La cible `make start` est un alias de `make restart`.

### `make check`

Exécute :

```text
Application/scripts/check-project.sh
```

```bash
make check
```

La cible `make status` est un alias de `make check`.

### `make minikube-start`

Démarre le profil défini par la variable :

```text
MINIKUBE_PROFILE
```

```bash
make minikube-start
```

### `make minikube-status`

Affiche l’état de ce profil.

```bash
make minikube-status
```

### `make minikube-stop`

Arrête ce profil sans le supprimer.

```bash
make minikube-stop
```

### `make pods`

Affiche tous les pods Kubernetes.

```bash
make pods
```

### `make namespaces`

Affiche les namespaces Kubernetes.

```bash
make namespaces
```

### `make releases`

Affiche toutes les releases Helm.

```bash
make releases
```

!!! warning "Deux parcours Minikube dans le Makefile"

    Les commandes `host-*` utilisent l’outil récent `tools/host/machina-host`.

    Les commandes `minikube-*`, `restart`, `check` et leurs alias appartiennent à un parcours plus ancien ou plus générique.

    Leur configuration doit être vérifiée avant usage, notamment la valeur de `MINIKUBE_PROFILE`.

    Pour le parcours actuellement documenté, privilégier les commandes `host-*` et `devcont-*`.

## Surcharger une variable

Les variables définies avec `?=` dans le Makefile peuvent être remplacées lors de l’appel.

### Changer le port MkDocs

```bash
make docs-serve DOCS_PORT=8002
```

### Changer le port Argo CD

```bash
make open-argocd ARGOCD_PORT=8090
```

### Choisir explicitement un profil Minikube

```bash
make minikube-status MINIKUBE_PROFILE=machina
```

### Changer temporairement un port Compose

```bash
make compose-config MACHINA_FRONT_PORT=8086
```

Pour une configuration Compose persistante, modifier plutôt :

```text
Application/.env
```

## Parcours courants

### Démarrer Docker Compose

```bash
make compose-config
make compose-up
make compose-status
```

### Arrêter Docker Compose

```bash
make compose-down
```

### Premier déploiement Minikube

Sur l’hôte Linux :

```bash
make host-bootstrap
```

Dans le Dev Container :

```bash
make k8s-connect
make devcont-bootstrap
make devcont-status
```

### Redémarrer un environnement Minikube existant

Sur l’hôte Linux :

```bash
make host-start
```

Dans le Dev Container :

```bash
make k8s-connect
make devcont-start
make devcont-status
```

### Arrêter l’environnement Minikube

Dans le Dev Container :

```bash
make devcont-stop
```

Sur l’hôte Linux :

```bash
make host-stop
```

### Travailler sur la documentation

```bash
make docs-install
make docs-check
make docs-serve
```

## Vérification avant commit

Avant de valider une modification documentaire :

```bash
make docs-check
git diff --check
git status --short
```

Pour une modification Kubernetes :

```bash
make validate-k8s
```

Pour une modification Docker Compose :

```bash
make compose-config
```

## Pages associées

- [Prérequis](prerequisites.md)
- [Dev Container et Minikube](devcontainer-minikube.md)
- [Docker Compose local](local-docker.md)
- [Dépannage](../operations/troubleshooting.md)
