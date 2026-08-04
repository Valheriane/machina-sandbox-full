# Machina Sandbox Full

Bienvenue dans la documentation technique de **Machina Sandbox Full**, le bac à sable utilisé pour expérimenter l’architecture du projet **MachinaControl**.

Ce dépôt permet de développer, tester et déployer une petite application distribuée autour de drones simulés, d’un broker MQTT, d’une API de gestion de flotte et d’une interface web.

!!! info "Un environnement expérimental"

Machina Sandbox Full est un environnement d’apprentissage et d’expérimentation.

Certaines briques, notamment le monitoring et GitOps, peuvent encore être incomplètes, facultatives ou en cours de modernisation. La documentation distingue autant que possible les fonctionnalités opérationnelles des éléments expérimentaux ou prévus.

## Composants principaux

Le bac à sable repose actuellement sur quatre composants applicatifs.

| Composant            | Rôle                                                       | Emplacement                 |
| -------------------- | ---------------------------------------------------------- | --------------------------- |
| Broker MQTT          | Transporte les commandes, la télémétrie et les événements  | `Application/broker/`       |
| Fleet API            | Gère la flotte de drones simulés et communique avec MQTT   | `Application/fleet-api/`    |
| Frontend             | Fournit l’interface web de contrôle et de visualisation    | `Application/front/`        |
| Simulateur de drones | Simule l’état, les déplacements et les messages des drones | `Application/agents/drone/` |

Pour une description plus détaillée, consulte la [vue générale de l’architecture](architecture/overview.md).

## Choisir un mode d’utilisation

Deux parcours principaux sont disponibles.

### Docker Compose local

Ce mode permet de lancer rapidement les services applicatifs avec Docker, sans utiliser Kubernetes.

Il est adapté pour :

- découvrir les composants ;
- développer localement ;
- vérifier les échanges entre les services ;
- tester l’application avec une configuration simple.

[:octicons-arrow-right-24: Démarrer avec Docker Compose](getting-started/local-docker.md)

### Dev Container, Minikube et Helm

Ce mode fournit un environnement de développement reproductible dans Visual Studio Code.

Il permet notamment d’utiliser :

- Python et Node.js ;
- Docker CLI et Docker Compose ;
- Kubernetes avec Minikube ;
- Helm ;
- kubectl ;
- kubeconform.

Le moteur Docker et le cluster Minikube fonctionnent sur la machine hôte. Le Dev Container utilise le moteur Docker de l’hôte et se connecte au réseau du cluster.

[:octicons-arrow-right-24: Démarrer avec le Dev Container et Minikube](getting-started/devcontainer-minikube.md)

## Architecture générale

Le flux applicatif principal est le suivant :

```text
Frontend
    |
    v
Fleet API
    |
    v
Broker MQTT
    |
    v
Simulateurs de drones
    |
    +--> Télémétrie
    +--> Événements
```

Les formats de messages, les topics MQTT et les mécanismes de signature doivent être vérifiés dans le code avant d’être considérés comme des contrats stables.

Consulte les pages suivantes pour approfondir l’architecture :

- [Vue générale](architecture/overview.md)
- [Réseau et ports](architecture/networking.md)
- [Flux de données](architecture/data-flow.md)
- [Comparaison des environnements](architecture/environments.md)

## Déploiement Kubernetes

Le chart Helm principal se trouve dans :

```text
Application/machina-sandbox/
```

Il constitue actuellement la source de déploiement Kubernetes la plus à jour du projet.

Les manifests plus anciens présents dans `Application/k8s/` doivent être vérifiés avant utilisation. Ils ne doivent pas être considérés automatiquement comme la source de vérité.

## GitOps et observabilité

Le dépôt contient également des expérimentations autour de :

- Helm ;
- Argo CD ;
- Prometheus ;
- Grafana ;
- Loki.

!!! warning "État variable des outils"

```
La présence d’un script ou d’un manifeste dans le dépôt ne garantit pas que la fonctionnalité soit actuellement installée ou opérationnelle.

Consulte les sections [Exploitation](operations/monitoring.md) et [GitOps](gitops/deployment-rules.md) avant d’utiliser ces composants.
```

## Premiers liens utiles

- [Prérequis](getting-started/prerequisites.md)
- [Commandes disponibles](getting-started/commands.md)
- [Dépannage](operations/troubleshooting.md)
- [Ajouter un nouveau service](integrations/add-a-service.md)
- [Règles de contribution](gitops/contribution-rules.md)

## À propos de cette documentation

La documentation est construite avec **MkDocs** et le thème **Material for MkDocs**.

Elle peut être validée avec :

```bash
make docs-check
```

Elle peut être consultée localement avec :

```bash
make docs-serve
```

Le serveur est accessible par défaut à l’adresse :

```text
http://localhost:8001
```
