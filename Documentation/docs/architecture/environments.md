# Environnements

Machina Sandbox Full peut être utilisé avec plusieurs niveaux d’environnement.

Chaque niveau répond à un besoin différent et ne doit pas être confondu avec les autres.

## Environnements principaux

| Environnement       | Rôle                                           |
| ------------------- | ---------------------------------------------- |
| Hôte Linux          | Exécute Docker, Visual Studio Code et Minikube |
| Dev Container       | Fournit les outils de développement            |
| Docker Compose      | Exécute les services sans Kubernetes           |
| Minikube            | Fournit un cluster Kubernetes local            |
| Helm                | Génère et installe les ressources Kubernetes   |
| GitOps avec Argo CD | Synchronisation expérimentale depuis Git       |

## Machine hôte Linux

La machine hôte exécute :

- Docker Engine ;
- Visual Studio Code ;
- Minikube ;
- le Dev Container ;
- les conteneurs Docker Compose ;
- le conteneur du nœud Minikube.

Les commandes de gestion du profil Minikube doivent être lancées depuis l’hôte :

```bash
make host-check
make host-bootstrap
make host-start
make host-status
make host-stop
make host-delete
```

## Dev Container

Le Dev Container fournit un environnement reproductible basé sur Ubuntu 24.04.

Il inclut notamment :

- Python 3.11 ;
- Node.js 20 ;
- npm ;
- Docker CLI ;
- Docker Compose ;
- `kubectl` ;
- Helm ;
- kubeconform.

Il utilise Docker-outside-of-Docker.

Le moteur Docker ne fonctionne donc pas dans le Dev Container : il reste sur la machine hôte.

## Docker Compose

Docker Compose est le mode le plus simple pour exécuter l’application.

Il utilise :

```text
Application/docker-compose.yml
```

Il démarre actuellement :

```text
broker
fleet-api
front
```

Le simulateur autonome n’est pas inclus.

### Avantages

- démarrage rapide ;
- peu de dépendances ;
- accès sur `localhost` ;
- logs simples à consulter ;
- adapté au développement local.

### Limites

- pas d’orchestration Kubernetes ;
- pas de release Helm ;
- pas de probes Kubernetes ;
- différences possibles avec le déploiement Minikube.

### Commandes principales

```bash
make compose-config
make compose-up
make compose-status
make compose-logs
make compose-down
```

## Minikube

Minikube fournit un cluster Kubernetes local.

Le profil utilisé par le projet est :

```text
machina
```

Il fonctionne sur l’hôte avec le pilote Docker.

Le Dev Container est ensuite connecté au réseau du cluster avec :

```bash
make k8s-connect
```

### Avantages

- environnement Kubernetes local ;
- Services et NodePorts ;
- probes de santé ;
- déploiement Helm ;
- comportement plus proche d’un environnement orchestré.

### Limites

- consommation de ressources supérieure ;
- démarrage plus long ;
- adresse IP dynamique ;
- images locales à charger dans le nœud ;
- persistance encore incomplète.

## Helm

Helm n’est pas un environnement d’exécution distinct.

Il sert à :

- définir les ressources Kubernetes ;
- paramétrer les images et les ports ;
- générer les manifests ;
- installer ou mettre à jour une release.

Le chart principal est :

```text
Application/machina-sandbox/
```

La release utilisée dans le parcours Dev Container est :

```text
machina-sandbox
```

Le namespace est :

```text
machina-sandbox
```

### Validation

```bash
make validate-k8s
```

### Déploiement

```bash
make devcont-deploy
```

## GitOps avec Argo CD

Argo CD peut surveiller un dépôt Git et synchroniser automatiquement les ressources Kubernetes.

Dans cette architecture :

- Helm décrit les ressources ;
- Argo CD peut utiliser le chart Helm présent dans Git ;
- les deux outils ne sont pas concurrents.

Les fichiers Argo CD présents dans :

```text
Application/k8s/argocd/
```

appartiennent actuellement à une expérimentation GitOps.

!!! warning "État expérimental"

    Argo CD ne doit pas être présenté comme une dépendance obligatoire du parcours local actuel.

    Le chart Helm peut être validé et déployé sans Argo CD.

## Comparaison

| Critère               | Docker Compose                      | Minikube et Helm                        |
| --------------------- | ----------------------------------- | --------------------------------------- |
| Orchestrateur         | Docker Compose                      | Kubernetes                              |
| Définition principale | `docker-compose.yml`                | chart Helm                              |
| Accès                 | `localhost`                         | IP Minikube et NodePorts                |
| Déploiement           | conteneurs Docker                   | Deployments et Services                 |
| Santé                 | pas de healthchecks Compose actuels | probes Kubernetes                       |
| Images                | construites directement             | construites puis chargées dans Minikube |
| Persistance SQLite    | montage hôte                        | non persistante actuellement            |
| Complexité            | faible                              | moyenne                                 |
| Usage conseillé       | développement rapide                | validation Kubernetes                   |

## Choisir un environnement

### Développement rapide

Utiliser Docker Compose pour :

- modifier Fleet API ;
- modifier le frontend ;
- vérifier les communications de base ;
- consulter rapidement les logs.

```bash
make compose-up
```

### Validation Kubernetes

Utiliser Minikube et Helm pour :

- vérifier le chart ;
- tester les probes ;
- tester les Services ;
- vérifier les NodePorts ;
- préparer les pratiques d’orchestration.

```bash
make devcont-deploy
```

### Travail sans Kubernetes

Le Dev Container reste utilisable même si Minikube n’est pas démarré.

Lors de son ouverture, le script de connexion Kubernetes fonctionne en mode non strict.

Il affiche alors un avertissement, mais ne bloque pas les outils Python, Node.js ou Docker Compose.

## Cycle de vie quotidien avec Minikube

### Sur l’hôte

```bash
make host-start
```

### Dans le Dev Container

```bash
make k8s-connect
make devcont-start
make devcont-status
```

### Arrêt de l’application

Dans le Dev Container :

```bash
make devcont-stop
```

### Arrêt du cluster

Sur l’hôte :

```bash
make host-stop
```

## Cycle de vie Docker Compose

### Démarrage

```bash
make compose-config
make compose-up
make compose-status
```

### Logs

```bash
make compose-logs
```

### Arrêt

```bash
make compose-down
```

## Données et persistance

### Docker Compose

Fleet API monte :

```text
Application/fleet-api/data/
```

dans le conteneur.

La base SQLite peut donc rester présente après l’arrêt des conteneurs.

### Kubernetes

Le chart Helm ne déclare actuellement aucun PersistentVolumeClaim pour Fleet API.

La base SQLite est stockée dans le système de fichiers du pod.

Elle peut être perdue lorsque le pod est remplacé.

## Configuration

### Docker Compose

Les variables locales sont définies dans :

```text
Application/.env
```

### Kubernetes

Les valeurs sont définies dans :

```text
Application/machina-sandbox/values.yaml
```

Certaines valeurs sont surchargées au moment du déploiement par le Makefile, notamment la configuration CORS.

### Dev Container

La configuration est définie dans :

```text
.devcontainer/devcontainer.json
.devcontainer/post-create.sh
.devcontainer/connect-minikube.sh
```

## Source de vérité par domaine

| Domaine                    | Source principale actuelle       |
| -------------------------- | -------------------------------- |
| Docker Compose             | `Application/docker-compose.yml` |
| Déploiement Kubernetes     | `Application/machina-sandbox/`   |
| Dev Container              | `.devcontainer/`                 |
| Commandes d’exploitation   | `Makefile`                       |
| Cycle de vie Minikube hôte | `tools/host/machina-host`        |
| Documentation              | `Documentation/docs/`            |

## Éléments historiques ou à vérifier

Les éléments suivants peuvent contenir des expérimentations plus anciennes :

```text
Application/k8s/
Application/scripts/
```

Ils ne doivent pas être considérés automatiquement comme la source de vérité.

Leur contenu doit être inspecté avant d’être utilisé ou documenté comme opérationnel.

## Pages associées

- [Vue générale](overview.md)
- [Réseau et ports](networking.md)
- [Flux de données](data-flow.md)
- [Docker Compose local](../getting-started/local-docker.md)
- [Dev Container et Minikube](../getting-started/devcontainer-minikube.md)
