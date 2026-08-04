# Dev Container et Minikube

Cette page décrit le parcours recommandé pour exécuter **Machina Sandbox Full** dans le Dev Container et le déployer sur un cluster Kubernetes local avec Minikube et Helm.

## Architecture de l’environnement

L’environnement repose sur plusieurs niveaux distincts :

| Niveau             | Rôle                                                  |
| ------------------ | ----------------------------------------------------- |
| Machine hôte Linux | Exécute Docker, Visual Studio Code et Minikube        |
| Dev Container      | Fournit les outils de développement et de déploiement |
| Conteneur Minikube | Héberge le nœud Kubernetes local                      |
| Pods Kubernetes    | Exécutent le broker, Fleet API et le frontend         |

!!! info "Docker-outside-of-Docker"

    Le Dev Container ne possède pas son propre moteur Docker.

    Il utilise le moteur Docker de la machine hôte grâce au socket Docker monté dans le conteneur.

    Les images construites depuis le Dev Container sont donc créées par le moteur Docker de l’hôte.

## Outils disponibles dans le Dev Container

Le Dev Container est basé sur Ubuntu 24.04 et fournit notamment :

- Python 3.11 ;
- Node.js 20 ;
- npm ;
- Docker CLI ;
- Docker Compose ;
- `kubectl` ;
- Helm ;
- kubeconform.

Sa configuration se trouve dans :

```text
.devcontainer/devcontainer.json
```

Le script exécuté lors de sa création est :

```text
.devcontainer/post-create.sh
```

Il installe les dépendances de Fleet API, du simulateur de drones et du frontend.

## Profil Minikube

Le profil utilisé par le projet s’appelle :

```text
machina
```

Minikube est lancé sur la machine hôte avec le pilote Docker.

Le cluster ne doit pas être créé directement à l’intérieur du Dev Container.

!!! warning "Terminal hôte ou Dev Container"

    Les commandes `make host-*` doivent être lancées depuis le terminal Linux de la machine hôte.

    Les commandes `make k8s-*` et `make devcont-*` doivent être lancées depuis le Dev Container.

## 1. Cloner le dépôt

Depuis le terminal Linux hôte :

```bash
git clone <adresse-du-depot>
cd machina-sandbox-full
```

Puis vérifier la branche active :

```bash
git status --short --branch
```

## 2. Vérifier l’environnement hôte

Toujours depuis le terminal Linux hôte :

```bash
make host-check
```

Cette commande vérifie notamment :

- le système Linux ;
- Docker ;
- Minikube ;
- l’existence du profil `machina` ;
- l’état du cluster.

Si l’environnement n’est pas encore préparé :

```bash
make host-bootstrap
```

Cette commande peut :

- installer Minikube si nécessaire ;
- créer ou démarrer le profil `machina` ;
- mettre à jour le contexte Kubernetes.

Si le profil existe déjà mais qu’il est arrêté :

```bash
make host-start
```

Pour afficher son état :

```bash
make host-status
```

## 3. Ouvrir le Dev Container

Ouvrir le dépôt dans Visual Studio Code.

Utiliser ensuite la palette de commandes :

```text
Dev Containers: Reopen in Container
```

Lors de la première création, Visual Studio Code exécute automatiquement :

```bash
make dev-install
```

Cette commande prépare :

- `Application/fleet-api/.venv/` ;
- `Application/agents/drone/.venv/` ;
- `Application/front/node_modules/` ;
- les répertoires Kubernetes du Dev Container.

!!! note "Durée de la première installation"

    La première ouverture peut prendre plusieurs minutes, car les dépendances Python et Node.js doivent être installées.

## 4. Connecter le Dev Container à Minikube

Dans le terminal du Dev Container :

```bash
make k8s-connect
```

Cette commande utilise :

```text
.devcontainer/connect-minikube.sh
```

Le script réalise notamment les opérations suivantes :

1. détecter le conteneur Docker Minikube ;
2. identifier le réseau Docker du profil `machina` ;
3. connecter le Dev Container à ce réseau ;
4. adapter le contexte Kubernetes ;
5. vérifier l’accès à l’API Kubernetes.

Une connexion réussie permet au Dev Container d’utiliser directement `kubectl` et Helm sur le cluster hôte.

## 5. Vérifier la connexion Kubernetes

Depuis le Dev Container :

```bash
make k8s-status
```

La commande affiche notamment :

- le contexte Kubernetes courant ;
- le nœud Minikube ;
- les pods présents ;
- les releases Helm.

Le contexte doit correspondre au cluster Minikube utilisé par le projet.

## 6. Valider le chart Helm

Avant le déploiement :

```bash
make validate-k8s
```

Cette commande réalise trois vérifications :

1. validation du chart avec `helm lint` ;
2. génération des manifests avec `helm template` ;
3. validation des ressources avec kubeconform.

Le chart principal se trouve dans :

```text
Application/machina-sandbox/
```

!!! info "Source de déploiement Kubernetes"

    Le chart Helm constitue actuellement la source de déploiement Kubernetes la plus à jour du projet.

    Les manifests présents dans `Application/k8s/` peuvent être plus anciens et doivent être vérifiés avant utilisation.

## 7. Premier déploiement

Pour construire les images, les charger dans Minikube et déployer l’application :

```bash
make devcont-bootstrap
```

Cette commande est un alias de la procédure complète de déploiement.

Il est également possible d’utiliser directement :

```bash
make devcont-deploy
```

Le déploiement réalise notamment :

1. la validation Helm et Kubernetes ;
2. la construction des images `fleet-api` et `front` ;
3. le chargement des images dans le nœud Minikube ;
4. l’installation ou la mise à jour de la release Helm ;
5. le redémarrage des déploiements ;
6. la vérification des services.

La release Helm utilisée est :

```text
machina-sandbox
```

Le namespace Kubernetes est :

```text
machina-sandbox
```

## 8. Vérifier le déploiement

Après le déploiement :

```bash
make devcont-check
```

Cette commande vérifie notamment :

- la release Helm ;
- le déploiement du broker ;
- le déploiement de Fleet API ;
- le déploiement du frontend ;
- l’endpoint de disponibilité de Fleet API ;
- l’accès au frontend ;
- l’accès au port MQTT WebSocket.

Pour obtenir une vue d’ensemble :

```bash
make devcont-status
```

Cette commande affiche :

- les releases Helm ;
- les déploiements ;
- les pods ;
- les services ;
- les URL d’accès calculées à partir de l’adresse actuelle de Minikube.

## Accès aux services

Les NodePorts actuellement configurés sont :

| Service     | Protocole      | NodePort |
| ----------- | -------------- | -------: |
| Broker MQTT | MQTT TCP       |  `31883` |
| Broker MQTT | MQTT WebSocket |  `30901` |
| Fleet API   | HTTP           |  `30800` |
| Frontend    | HTTP           |  `32449` |

L’adresse IP du nœud Minikube est dynamique.

Il ne faut donc pas enregistrer une adresse comme `192.168.x.x` dans les scripts ou la documentation.

Pour récupérer les URL courantes :

```bash
make devcont-status
```

La sortie fournit notamment une adresse de la forme :

```text
Front : http://<IP_MINIKUBE>:32449
API   : http://<IP_MINIKUBE>:30800
MQTT  : ws://<IP_MINIKUBE>:30901
```

## Redémarrer une application déjà déployée

Lorsque la release Helm existe déjà et que les images n’ont pas besoin d’être reconstruites :

```bash
make devcont-start
```

Cette commande remet les déploiements à une réplique et attend leur disponibilité.

Elle démarre les composants dans l’ordre suivant :

1. broker MQTT ;
2. Fleet API ;
3. frontend.

!!! warning "Release requise"

    `make devcont-start` ne réalise pas une première installation.

    Si la release Helm n’existe pas encore, utiliser d’abord :

    ```bash
    make devcont-bootstrap
    ```

## Arrêter l’application

Pour arrêter les services applicatifs sans supprimer la release Helm ni le cluster :

```bash
make devcont-stop
```

Cette commande réduit à zéro le nombre de répliques des déploiements :

- Fleet API ;
- frontend ;
- broker MQTT.

Le cluster Minikube reste actif.

Pour redémarrer ensuite l’application :

```bash
make devcont-start
```

## Arrêter Minikube

Cette opération doit être effectuée depuis le terminal Linux hôte :

```bash
make host-stop
```

Elle arrête le profil Minikube sans le supprimer.

Pour le redémarrer :

```bash
make host-start
```

Après le redémarrage du cluster, il peut être nécessaire de reconnecter le Dev Container :

```bash
make k8s-connect
```

## Supprimer le cluster

Depuis le terminal Linux hôte :

```bash
make host-delete
```

La commande demande une confirmation avant de supprimer le profil.

!!! danger "Suppression du cluster"

    La suppression détruit les ressources Kubernetes, les releases Helm et les données conservées uniquement dans le cluster.

    Elle ne doit pas être utilisée pour un simple arrêt temporaire.

## Ordre recommandé au quotidien

Lorsque le cluster et la release existent déjà :

### Sur l’hôte Linux

```bash
make host-start
```

### Dans le Dev Container

```bash
make k8s-connect
make devcont-start
make devcont-status
```

Pour arrêter l’environnement :

### Dans le Dev Container

```bash
make devcont-stop
```

### Sur l’hôte Linux

```bash
make host-stop
```

## Résumé des commandes

| Commande                 | Environnement | Rôle                                       |
| ------------------------ | ------------- | ------------------------------------------ |
| `make host-check`        | Hôte Linux    | Vérifie Docker, Minikube et le profil      |
| `make host-bootstrap`    | Hôte Linux    | Prépare Minikube et démarre le cluster     |
| `make host-start`        | Hôte Linux    | Démarre le profil existant                 |
| `make host-status`       | Hôte Linux    | Affiche l’état du profil                   |
| `make host-stop`         | Hôte Linux    | Arrête le profil sans le supprimer         |
| `make host-delete`       | Hôte Linux    | Supprime le profil après confirmation      |
| `make k8s-connect`       | Dev Container | Connecte le Dev Container au cluster       |
| `make k8s-status`        | Dev Container | Vérifie la connexion Kubernetes            |
| `make validate-k8s`      | Dev Container | Valide le chart et les manifests générés   |
| `make devcont-bootstrap` | Dev Container | Réalise le premier déploiement             |
| `make devcont-deploy`    | Dev Container | Construit, charge et déploie l’application |
| `make devcont-check`     | Dev Container | Vérifie le déploiement                     |
| `make devcont-status`    | Dev Container | Affiche les ressources et les URL          |
| `make devcont-start`     | Dev Container | Redémarre une release existante            |
| `make devcont-stop`      | Dev Container | Arrête les services applicatifs            |

## Dépannage rapide

Si `make k8s-connect` échoue :

1. quitter le Dev Container ;
2. vérifier le cluster depuis l’hôte :

   ```bash
   make host-status
   ```

3. démarrer le profil si nécessaire :

   ```bash
   make host-start
   ```

4. revenir dans le Dev Container ;
5. relancer :

   ```bash
   make k8s-connect
   ```

Pour un diagnostic plus détaillé, consulte la page [Dépannage](../operations/troubleshooting.md).

## Étape suivante

Pour exécuter l’application sans Kubernetes, consulte :

[Docker Compose local](local-docker.md)
