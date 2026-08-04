# Scripts d’exploitation

Le projet **Machina Sandbox Full** fournit plusieurs scripts et cibles Make pour préparer, démarrer, vérifier et arrêter ses environnements.

Le point d’entrée recommandé est généralement le fichier :

```text
Makefile
```

Les scripts Bash situés dans le dépôt réalisent les opérations détaillées, tandis que les commandes `make` fournissent une interface plus courte et plus cohérente.

## Objectifs

Cette page explique :

- où se trouvent les scripts ;
- comment afficher les commandes disponibles ;
- quelles commandes lancer sur l’hôte Linux ;
- quelles commandes lancer dans le Dev Container ;
- comment piloter Docker Compose ;
- comment déployer dans Minikube ;
- comment utiliser les scripts de vérification ;
- quelles commandes sont encore historiques ou expérimentales ;
- quelles précautions prendre avant d’exécuter un script.

## Organisation générale

Les principaux fichiers d’exploitation sont répartis ainsi :

```text
Makefile

tools/
└── host/
    └── machina-host

.devcontainer/
├── connect-minikube.sh
├── post-create.sh
├── devcontainer.json
└── devcontainer-lock.json

Application/
└── scripts/
    ├── check-project.sh
    ├── check-monitoring.sh
    ├── check-prometheus.sh
    ├── check-loki.sh
    ├── check-argocd.sh
    ├── open-grafana.sh
    ├── open-argocd.sh
    └── restart-project.sh
```

## Trois contextes d’exécution

Le projet distingue trois contextes.

| Contexte               | Rôle                                                   |
| ---------------------- | ------------------------------------------------------ |
| hôte Linux             | exécuter Docker et piloter le cycle de vie de Minikube |
| Dev Container          | développer, valider et déployer dans Minikube          |
| conteneurs applicatifs | exécuter les services du projet                        |

Le terminal utilisé est important.

Certaines commandes ne fonctionnent volontairement que sur l’hôte, tandis que d’autres sont conçues pour le Dev Container.

## Identifier son terminal

Dans le Dev Container, le chemin courant ressemble généralement à :

```text
/workspaces/machina-sandbox-full
```

Le terminal de l’hôte utilise plutôt le chemin réel du dépôt sur la machine.

Pour vérifier si le terminal se trouve dans un conteneur :

```bash
test -f /.dockerenv \
  && echo "Dev Container ou conteneur Docker" \
  || echo "Machine hôte"
```

Cette vérification reste indicative. Le Makefile utilise également la variable :

```text
REMOTE_CONTAINERS
```

pour détecter le Dev Container.

---

# Utiliser le Makefile

## Afficher l’aide

Depuis la racine du dépôt :

```bash
make help
```

La commande affiche les cibles disposant d’une description placée après :

```text
##
```

Exemple dans le Makefile :

```make
compose-status: ## Affiche l'état et les ports des services Docker Compose
```

## Afficher les versions

```bash
make versions
```

Cette cible vérifie notamment :

```text
git
docker
kubectl
helm
minikube
python3
node
npm
```

Elle permet de repérer rapidement un outil absent ou une version inattendue.

## Rendre les scripts exécutables

```bash
make permissions
```

Cette cible applique le droit d’exécution aux scripts situés dans :

```text
Application/scripts/
```

Elle n’installe aucun outil et ne démarre aucun service.

!!! note "Outil hôte"

    Le fichier suivant doit également conserver son droit d’exécution :

    ```text
    tools/host/machina-host
    ```

    Son état peut être vérifié avec :

    ```bash
    ls -l tools/host/machina-host
    ```

---

# Commandes réservées à l’hôte

## Pourquoi certaines commandes sont bloquées

Le Makefile contient une garde appelée :

```text
ensure-local
```

Elle interrompt certaines commandes lorsqu’elles sont lancées dans le Dev Container.

Le message affiché est :

```text
Cette commande pilote le Minikube de la machine hôte.
Quitte le Dev Container puis relance-la depuis le terminal local.
```

Ce comportement est volontaire.

Le moteur Docker et le conteneur Minikube s’exécutent sur la machine hôte. Leur cycle de vie doit rester contrôlé depuis cet environnement.

## Outil principal

Le script consacré à Minikube sur l’hôte est :

```text
tools/host/machina-host
```

Il est appelé par les cibles :

```text
host-bootstrap
host-check
host-start
host-status
host-stop
host-delete
```

## Vérifier l’environnement hôte

Depuis un terminal Linux local, à la racine du dépôt :

```bash
make host-check
```

Cette commande vérifie notamment la présence et l’état des outils nécessaires au cluster local.

## Afficher l’état de Minikube

```bash
make host-status
```

Le profil attendu pour le projet est :

```text
machina
```

La commande brute équivalente est :

```bash
minikube status -p machina
```

## Démarrer Minikube

```bash
make host-start
```

La commande brute équivalente est :

```bash
minikube start -p machina
```

Cette opération démarre un profil existant.

Elle ne recrée pas volontairement le cluster lorsqu’il existe déjà.

## Préparer Minikube pour la première fois

```bash
make host-bootstrap
```

Cette cible est destinée à la préparation initiale du profil hôte.

Avant de l’utiliser, vérifier :

```bash
make host-status
```

Elle ne doit pas être utilisée comme commande quotidienne lorsque le profil existe déjà.

## Arrêter Minikube

```bash
make host-stop
```

Cette opération arrête le cluster sans le supprimer.

La commande brute correspondante est :

```bash
minikube stop -p machina
```

Les ressources Kubernetes doivent normalement être retrouvées au prochain démarrage.

## Supprimer Minikube

La cible suivante existe :

```text
host-delete
```

!!! danger "Suppression du cluster"

    Ne pas exécuter :

    ```bash
    make host-delete
    ```

    sans avoir vérifié :

    - le profil ciblé ;
    - les données présentes ;
    - les releases Helm ;
    - les volumes persistants ;
    - les ressources de monitoring ;
    - les ressources Argo CD ;
    - les éventuelles sauvegardes.

    La suppression d’un profil Minikube supprime l’environnement Kubernetes local associé.

## Anciennes cibles Minikube

Le Makefile peut également contenir :

```text
minikube-start
minikube-stop
minikube-status
```

Ces cibles dépendent de la variable :

```text
MINIKUBE_PROFILE
```

Leur valeur doit être vérifiée avant utilisation :

```bash
make --eval \
  | grep '^MINIKUBE_PROFILE'
```

Pour éviter une confusion de profil, les cibles `host-*` sont préférables pour le cycle de vie du cluster hôte.

---

# Préparation du Dev Container

## Script post-création

Le fichier :

```text
.devcontainer/post-create.sh
```

prépare l’environnement de développement.

Il réalise notamment :

- la création des environnements virtuels Python ;
- l’installation des dépendances de Fleet API ;
- l’installation des dépendances du simulateur autonome ;
- la vérification des dépendances Python ;
- l’installation du frontend avec `npm ci` ;
- la préparation des répertoires Kubernetes.

## Exécution automatique

Le Dev Container appelle normalement ce script lors de sa création.

La cible Make correspondante est :

```bash
make dev-install
```

Cette commande peut être relancée lorsque les dépendances ont changé.

## Environnements Python

Les environnements virtuels utilisés sont notamment :

```text
Application/fleet-api/.venv
Application/agents/drone/.venv
```

Exemple pour exécuter Python dans Fleet API :

```bash
Application/fleet-api/.venv/bin/python \
  --version
```

Il n’est pas nécessaire d’activer manuellement le virtualenv pour utiliser son interpréteur.

## Installation frontend

Le script utilise :

```bash
npm ci
```

Il exige donc la présence de :

```text
Application/front/package-lock.json
```

La création silencieuse d’un nouveau lockfile est volontairement évitée.

---

# Connexion à Minikube depuis le Dev Container

## Script de connexion

Le fichier :

```text
.devcontainer/connect-minikube.sh
```

connecte le Dev Container au profil Minikube exécuté sur l’hôte.

Il vérifie notamment :

- le conteneur Docker Minikube ;
- le réseau Docker utilisé ;
- l’adresse du serveur Kubernetes ;
- le contexte Kubernetes ;
- l’accès à l’API Kubernetes.

## Commande recommandée

Dans le Dev Container :

```bash
make k8s-connect
```

Résultat attendu — ne pas copier :

```text
[MINIKUBE] Connexion au cluster Kubernetes 'machina'...
[OK] Connexion Kubernetes opérationnelle.
Contexte : machina
```

L’adresse IP affichée peut changer après un redémarrage.

Elle ne doit pas être enregistrée comme une valeur permanente dans la documentation ou la configuration Git.

## Vérification complète

```bash
make k8s-status
```

Cette cible affiche notamment :

- le contexte Kubernetes ;
- les nœuds ;
- les pods de tous les namespaces ;
- les releases Helm.

## Connexion et déploiement

Les principales cibles `devcont-*` appellent automatiquement :

```text
k8s-connect
```

Il n’est donc pas nécessaire de la lancer séparément avant chaque commande.

Elle reste utile pour diagnostiquer uniquement la connexion.

---

# Déploiement depuis le Dev Container

## Variables principales

Le déploiement utilise notamment :

```text
DEVCONT_MINIKUBE_CONTAINER
DEVCONT_NAMESPACE
DEVCONT_RELEASE
DEVCONT_CHART
```

Les valeurs attendues sont proches de :

```text
Conteneur Minikube : machina
Namespace          : machina-sandbox
Release            : machina-sandbox
Chart              : Application/machina-sandbox
```

## Première installation complète

```bash
make devcont-bootstrap
```

Cette cible utilise le même parcours que :

```bash
make devcont-deploy
```

Elle convient à une première installation de l’application dans un cluster disponible.

## Déploiement complet

```bash
make devcont-deploy
```

Cette cible effectue successivement :

1. la connexion à Minikube ;
2. la validation du chart ;
3. la construction des images ;
4. le chargement des images dans Minikube ;
5. l’installation ou la mise à jour Helm ;
6. le redémarrage des Deployments nécessaires ;
7. l’attente des rollouts ;
8. le contrôle fonctionnel.

## Validation Kubernetes

La cible appelée pendant le déploiement est :

```bash
make validate-k8s
```

Elle réalise :

```text
helm lint
helm template
kubeconform
```

Le manifeste rendu est écrit dans :

```text
/tmp/machina-rendered.yaml
```

## Construction des images

```bash
make devcont-build-images
```

Cette cible construit notamment :

```text
fleet-api:latest
front:latest
```

Elle vérifie également l’image :

```text
eclipse-mosquitto:2
```

Elle ne déploie pas les images.

## Chargement des images

```bash
make devcont-load-images
```

Cette cible transfère les images dans le nœud Minikube.

Elle est nécessaire parce que le chart utilise des images locales avec une politique proche de :

```text
imagePullPolicy: Never
```

## Redémarrer une release existante

```bash
make devcont-start
```

Cette cible :

- vérifie que la release existe ;
- remet les répliques à `1` ;
- démarre d’abord le broker ;
- démarre ensuite Fleet API et le frontend ;
- attend les rollouts ;
- lance les contrôles.

Elle ne reconstruit pas les images.

## Arrêter l’application sans supprimer la release

```bash
make devcont-stop
```

Cette commande réduit les Deployments à zéro réplique.

Elle ne supprime pas :

- la release Helm ;
- le namespace ;
- Minikube ;
- les images ;
- la configuration Helm.

## Afficher l’état

```bash
make devcont-status
```

Cette cible affiche :

- la release Helm ;
- les Deployments ;
- les pods ;
- les Services ;
- les URL calculées avec l’adresse actuelle de Minikube.

## Vérification fonctionnelle

```bash
make devcont-check
```

Cette cible vérifie notamment :

- l’état de la release Helm ;
- le rollout du broker ;
- le rollout de Fleet API ;
- le rollout du frontend ;
- la route `/ready` de Fleet API ;
- l’accès HTTP au frontend ;
- l’ouverture du port MQTT WebSocket.

!!! warning "Fleet API et MQTT"

    La route `/ready` dépend de la connexion MQTT.

    Une Fleet API démarrée peut donc être considérée comme non prête si le broker est indisponible.

---

# Docker Compose

Les commandes Docker Compose peuvent être utilisées depuis le Dev Container grâce à l’accès au moteur Docker de l’hôte.

## Valider la configuration

```bash
make compose-config
```

Cette commande vérifie la configuration sans démarrer les services.

## Construire et démarrer

```bash
make compose-up
```

Les services actuels sont :

```text
broker
fleet-api
front
```

## Afficher l’état

```bash
make compose-status
```

## Suivre les logs

```bash
make compose-logs
```

Cette cible affiche les 100 dernières lignes puis suit les nouvelles sorties.

Pour quitter :

```text
Ctrl+C
```

Les conteneurs restent actifs.

## Redémarrer

```bash
make compose-restart
```

Cette cible redémarre les conteneurs existants sans reconstruire automatiquement toutes les images.

## Arrêter

```bash
make compose-down
```

Cette cible arrête Docker Compose.

Elle n’utilise pas d’option explicite de suppression des volumes.

---

# Scripts de contrôle historiques

Le dossier :

```text
Application/scripts/
```

contient plusieurs scripts créés avant la mise en place complète du nouveau parcours Dev Container.

Ils restent utiles, mais doivent être compris avant utilisation.

## `check-project.sh`

```text
Application/scripts/check-project.sh
```

Ce script effectue un contrôle global de l’ancien environnement.

Il recherche notamment :

- les namespaces applicatifs ;
- le namespace `monitoring` ;
- le namespace `argocd` ;
- les releases Helm ;
- les pods Grafana ;
- les pods Prometheus ;
- les pods Loki ;
- les applications Argo CD ;
- certains Services connus.

!!! warning "Hypothèses historiques"

    Ce script suppose que le monitoring et Argo CD ont déjà été installés.

    Leur absence peut donc produire des avertissements, même si l’application Machina fonctionne correctement.

## `restart-project.sh`

```text
Application/scripts/restart-project.sh
```

Ce script :

- vérifie plusieurs outils ;
- démarre Minikube ;
- vérifie le cluster ;
- affiche les nœuds ;
- affiche les namespaces ;
- affiche les releases ;
- inspecte le monitoring ;
- inspecte les pods applicatifs ;
- affiche certaines informations d’accès.

Il utilise historiquement :

```bash
minikube start
```

sans toujours préciser explicitement le profil `machina`.

!!! warning "Script historique"

    Pour le cycle de vie actuel du cluster, préférer :

    ```bash
    make host-start
    ```

    puis, dans le Dev Container :

    ```bash
    make k8s-connect
    ```

## Affichage de secrets

Certains scripts historiques récupèrent ou affichent :

- le mot de passe administrateur Grafana ;
- le mot de passe administrateur initial Argo CD.

Ne pas :

- copier ces sorties dans la documentation ;
- les publier dans une issue ;
- les envoyer dans une conversation ;
- les enregistrer dans Git ;
- les capturer dans des logs partagés.

---

# Scripts de monitoring

## État actuel

Les scripts suivants existent :

```text
Application/scripts/check-monitoring.sh
Application/scripts/check-prometheus.sh
Application/scripts/check-loki.sh
Application/scripts/open-grafana.sh
```

Cependant, le monitoring n’est actuellement pas déployé dans le namespace :

```text
monitoring
```

Ces scripts doivent donc être considérés comme des outils préparés pour une installation future.

## `check-monitoring.sh`

Ce script affiche :

- les pods du namespace `monitoring` ;
- les Services ;
- les releases Helm ;
- les pods contenant `loki` ;
- les pods contenant `prometheus` ;
- les pods contenant `grafana`.

Il ne réalise aucune installation.

## `check-prometheus.sh`

Ce script :

- recherche les pods Prometheus ;
- recherche les Services Prometheus ;
- crée un pod temporaire utilisant `curl` ;
- appelle l’endpoint de disponibilité de Prometheus.

Le pod temporaire utilise une image externe.

Le premier test peut donc nécessiter un téléchargement.

## `check-loki.sh`

Ce script :

- recherche les pods Loki ;
- recherche les Services Loki ;
- crée un pod temporaire utilisant `curl` ;
- appelle l’endpoint `/ready` de Loki.

Il ne vérifie pas à lui seul qu’un collecteur transmet effectivement les logs à Loki.

## `open-grafana.sh`

Ce script ouvre un port-forward :

```text
localhost:3000 → monitoring-grafana:80
```

Il suppose que le Service suivant existe :

```text
monitoring-grafana
```

Il ne démarre pas Grafana et ne l’installe pas.

## Cibles Make associées

Les anciennes cibles sont notamment :

```text
check-monitoring
check-prometheus
check-loki
open-grafana
```

Elles dépendent actuellement de :

```text
ensure-local
```

Elles doivent donc être lancées sur l’hôte, et non dans le Dev Container.

Cette organisation sera probablement adaptée lors de la remise en place reproductible du monitoring.

---

# Scripts Argo CD

## `check-argocd.sh`

```text
Application/scripts/check-argocd.sh
```

Ce script inspecte notamment :

- le namespace `argocd` ;
- les pods ;
- les Services ;
- les Applications Argo CD ;
- le Secret administrateur initial.

Il ne réalise pas l’installation d’Argo CD.

## `open-argocd.sh`

```text
Application/scripts/open-argocd.sh
```

Ce script vérifie notamment :

- l’existence du namespace `argocd` ;
- l’existence du Service `argocd-server` ;
- la disponibilité du Secret administrateur initial.

Il ouvre ensuite un port-forward vers :

```text
svc/argocd-server
```

## Port par défaut

Le Makefile prévoit une variable :

```text
ARGOCD_PORT
```

Exemple de surcharge :

```bash
make open-argocd ARGOCD_PORT=8090
```

Cette commande doit actuellement être exécutée depuis l’hôte en raison de `ensure-local`.

## Arrêter le port-forward

Un port-forward garde le terminal occupé.

Pour l’arrêter :

```text
Ctrl+C
```

Cette action n’arrête pas Argo CD.

## État expérimental

La présence des scripts et des manifests Argo CD ne signifie pas qu’Argo CD est actuellement installé.

Les commandes doivent d’abord vérifier :

```bash
kubectl get namespace argocd
```

```bash
kubectl get pods \
  --namespace argocd
```

---

# Documentation

Le Makefile contient aussi des cibles pour MkDocs.

## Installer les dépendances

```bash
make docs-install
```

Cette cible prépare l’environnement virtuel de documentation dans :

```text
Documentation/.venv
```

## Vérifier la documentation

```bash
make docs-check
```

Cette commande vérifie la construction stricte du site.

## Construire le site

```bash
make docs-build
```

Le site généré est placé dans :

```text
Documentation/site/
```

Ce dossier ne doit pas être versionné.

## Servir la documentation

```bash
make docs-serve
```

L’interface est disponible sur :

```text
http://localhost:8001
```

Le terminal reste occupé tant que le serveur fonctionne.

Pour l’arrêter :

```text
Ctrl+C
```

## Nettoyer le site généré

```bash
make docs-clean
```

Cette cible supprime seulement le site généré, pas les sources Markdown.

---

# Choisir la bonne commande

## Démarrer Minikube

Terminal hôte :

```bash
make host-start
```

## Vérifier Minikube

Terminal hôte :

```bash
make host-status
```

## Connecter le Dev Container

Dev Container :

```bash
make k8s-connect
```

## Déployer l’application

Dev Container :

```bash
make devcont-deploy
```

## Redémarrer sans reconstruire

Dev Container :

```bash
make devcont-start
```

## Arrêter l’application sans supprimer Helm

Dev Container :

```bash
make devcont-stop
```

## Utiliser Docker Compose

Dev Container :

```bash
make compose-up
```

## Vérifier la documentation

Dev Container :

```bash
make docs-check
```

---

# Tableau récapitulatif

| Commande              | Terminal          | Effet principal                  |
| --------------------- | ----------------- | -------------------------------- |
| `make host-check`     | hôte              | vérifie l’environnement Minikube |
| `make host-status`    | hôte              | affiche l’état du profil         |
| `make host-start`     | hôte              | démarre Minikube                 |
| `make host-stop`      | hôte              | arrête Minikube                  |
| `make k8s-connect`    | Dev Container     | connecte `kubectl` au cluster    |
| `make k8s-status`     | Dev Container     | affiche l’état Kubernetes        |
| `make devcont-deploy` | Dev Container     | construit et déploie avec Helm   |
| `make devcont-start`  | Dev Container     | remet les répliques à un         |
| `make devcont-stop`   | Dev Container     | met les répliques à zéro         |
| `make devcont-check`  | Dev Container     | vérifie l’application            |
| `make devcont-status` | Dev Container     | affiche ressources et URL        |
| `make compose-up`     | Dev Container     | démarre Docker Compose           |
| `make compose-down`   | Dev Container     | arrête Docker Compose            |
| `make compose-logs`   | Dev Container     | suit les logs Compose            |
| `make validate-k8s`   | Dev Container     | valide le chart hors ligne       |
| `make docs-check`     | Dev Container     | valide MkDocs                    |
| `make open-grafana`   | hôte actuellement | ouvre un port-forward Grafana    |
| `make open-argocd`    | hôte actuellement | ouvre un port-forward Argo CD    |

---

# Exécuter directement un script

L’utilisation de `make` est généralement préférable.

Un script peut néanmoins être exécuté directement lorsqu’il faut l’étudier ou le diagnostiquer.

Exemple :

```bash
bash .devcontainer/connect-minikube.sh
```

ou :

```bash
bash Application/scripts/check-monitoring.sh
```

L’exécution directe contourne certaines protections du Makefile.

!!! warning "Protections contournées"

    Lancer directement un script peut contourner :

    - `ensure-local` ;
    - la mise en place des permissions ;
    - certaines variables du Makefile ;
    - certaines vérifications préalables.

    Avant une exécution directe, lire le fichier :

    ```bash
    sed -n '1,260p' chemin/du/script.sh
    ```

---

# Modifier un script

## Lire avant de modifier

```bash
nl -ba chemin/du/script.sh \
  | sed -n '1,260p'
```

`nl -ba` affiche les numéros de ligne.

## Vérifier la syntaxe Bash

```bash
bash -n chemin/du/script.sh
```

Une sortie vide signifie que Bash n’a pas détecté d’erreur de syntaxe.

Cela ne garantit pas que le script fonctionnera correctement.

## Vérifier les caractères invisibles

```bash
sed -n '1,260l' chemin/du/script.sh
```

Cette commande peut aider à repérer :

- des caractères invisibles ;
- des fins de ligne Windows ;
- un point isolé ;
- des espaces inattendus ;
- des tabulations.

## Vérifier les droits

```bash
ls -l chemin/du/script.sh
```

## Comparer avec Git

```bash
git diff -- chemin/du/script.sh
```

## Vérifier avant commit

```bash
git diff --check
```

---

# Bonnes pratiques

## Utiliser `set -euo pipefail`

Pour les nouveaux scripts, une base fréquente est :

```bash
set -euo pipefail
```

Elle doit être utilisée en comprenant ses effets :

- `-e` arrête sur certaines erreurs ;
- `-u` considère une variable absente comme une erreur ;
- `pipefail` propage l’échec dans un pipeline.

## Citer les variables

Préférer :

```bash
"$VARIABLE"
```

à :

```bash
$VARIABLE
```

Cela évite plusieurs erreurs liées aux espaces et aux valeurs vides.

## Vérifier avant d’agir

Avant une action destructive :

```bash
kubectl get namespace nom
helm list --all-namespaces
minikube profile list
```

## Préférer les commandes idempotentes

Exemple Helm :

```text
helm upgrade --install
```

Cette commande peut installer une release absente ou mettre à jour une release existante.

## Produire des erreurs claires

Un script doit indiquer :

- ce qui manque ;
- le contexte utilisé ;
- le namespace ciblé ;
- le profil ciblé ;
- la commande de correction possible.

## Ne pas masquer toutes les erreurs

L’utilisation de :

```bash
|| true
```

est utile pour une vérification facultative.

Elle ne doit pas être utilisée autour d’une opération essentielle au risque de cacher un échec réel.

## Ne pas afficher les secrets

Un script ne doit jamais afficher automatiquement :

- un token GitHub ;
- un secret MQTT ;
- une clé privée ;
- un mot de passe de base de données ;
- un Secret Kubernetes complet.

Les scripts historiques qui affichent un mot de passe devront être revus lors de la remise en place de l’observabilité et de GitOps.

---

# Évolutions prévues

La future installation du monitoring et d’Argo CD devra probablement ajouter des commandes dédiées au Dev Container.

Exemples possibles :

```text
devcont-check-monitoring
devcont-check-prometheus
devcont-check-loki
devcont-check-argocd
devcont-open-grafana
devcont-open-prometheus
devcont-open-argocd
```

Les noms définitifs seront choisis après l’installation et l’audit.

L’objectif sera de conserver une séparation claire :

```text
host-*     → cycle de vie de Minikube sur l’hôte
devcont-*  → opérations Kubernetes depuis le Dev Container
compose-*  → environnement Docker Compose
docs-*     → documentation MkDocs
```

---

# Limites actuelles

| Élément                    | Limite actuelle                                                     |
| -------------------------- | ------------------------------------------------------------------- |
| scripts monitoring         | supposent des composants déjà installés                             |
| `open-grafana.sh`          | suppose le Service Grafana existant                                 |
| scripts Argo CD            | supposent Argo CD déjà installé                                     |
| `restart-project.sh`       | logique historique à harmoniser                                     |
| secrets                    | certains scripts historiques peuvent les afficher                   |
| commandes monitoring       | encore protégées par `ensure-local`                                 |
| profil Minikube historique | certaines anciennes cibles peuvent utiliser une variable différente |
| installation observabilité | non reproductible actuellement                                      |
| installation Argo CD       | non reproductible actuellement                                      |

## Pages associées

- [Commandes disponibles](../getting-started/commands.md)
- [Dev Container et Minikube](../getting-started/devcontainer-minikube.md)
- [Docker Compose local](../getting-started/local-docker.md)
- [Consulter les logs](logging.md)
- [Monitoring](monitoring.md)
- [Dépannage](troubleshooting.md)
- [Règles de déploiement](../gitops/deployment-rules.md)
