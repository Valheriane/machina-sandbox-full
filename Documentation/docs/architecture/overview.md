# Vue générale de l’architecture

**Machina Sandbox Full** est une application distribuée expérimentale construite autour de communications HTTP et MQTT.

Elle permet de gérer une flotte de drones simulés depuis une interface web, d’envoyer des commandes et de recevoir de la télémétrie et des événements.

## Composants principaux

| Composant      | Rôle                                                       | Emplacement                    |
| -------------- | ---------------------------------------------------------- | ------------------------------ |
| Broker MQTT    | Transporte les commandes, la télémétrie et les événements  | `Application/broker/`          |
| Fleet API      | Expose l’API HTTP et publie les commandes MQTT             | `Application/fleet-api/`       |
| Frontend       | Fournit l’interface web et consomme HTTP et MQTT WebSocket | `Application/front/`           |
| Agent de drone | Simule un drone et communique avec le broker               | `Application/agents/drone/`    |
| Chart Helm     | Décrit le déploiement Kubernetes principal                 | `Application/machina-sandbox/` |

## Architecture fonctionnelle

Le flux général est le suivant :

```text
Utilisateur
    |
    v
Frontend
    |
    +-----------------------+
    |                       |
    v                       v
Fleet API              Broker MQTT
    |                       |
    | commandes MQTT        | télémétrie et événements
    +---------------------->|
                            |
                            v
                    Simulateur de drone
```

Le frontend utilise deux canaux différents :

- HTTP vers Fleet API pour les opérations de gestion ;
- MQTT sur WebSocket pour recevoir les messages publiés par les drones.

Fleet API publie les commandes destinées aux drones sur le broker MQTT.

## Broker MQTT

Le broker utilise l’image :

```text
eclipse-mosquitto:2
```

Il écoute actuellement sur trois ports internes :

|   Port | Protocole      | Utilisation                                      |
| -----: | -------------- | ------------------------------------------------ |
| `1883` | MQTT TCP       | échanges MQTT entre services et agents           |
| `9001` | MQTT WebSocket | connexion MQTT depuis le navigateur              |
| `9883` | HTTP           | interface HTTP interne configurée dans Mosquitto |

En Kubernetes, seuls les ports `1883` et `9001` sont publiés par le Service `broker`.

Le port `9883` existe dans le conteneur, mais n’est pas actuellement exposé par un Service Kubernetes.

Le broker accepte actuellement les connexions anonymes :

```text
allow_anonymous true
```

!!! warning "Configuration de développement"

    L’accès anonyme est adapté à un bac à sable local, mais ne constitue pas une configuration adaptée à un environnement exposé ou de production.

## Fleet API

Fleet API est développée avec Python et FastAPI.

Elle assure notamment :

- la création et la gestion des drones ;
- le démarrage et l’arrêt des simulations ;
- l’envoi de commandes ;
- la publication MQTT ;
- l’accès aux états applicatifs ;
- les contrôles de santé et de disponibilité.

Les routes HTTP actuellement déclarées sont :

| Méthode  | Route                      | Rôle général             |
| -------- | -------------------------- | ------------------------ |
| `GET`    | `/health`                  | santé du processus HTTP  |
| `GET`    | `/ready`                   | disponibilité du service |
| `POST`   | `/drones`                  | création d’un drone      |
| `GET`    | `/drones`                  | liste des drones         |
| `GET`    | `/drones/{drone_id}`       | consultation d’un drone  |
| `PATCH`  | `/drones/{drone_id}`       | modification d’un drone  |
| `DELETE` | `/drones/{drone_id}`       | suppression d’un drone   |
| `POST`   | `/drones/{drone_id}/start` | démarrage                |
| `POST`   | `/drones/{drone_id}/stop`  | arrêt                    |
| `POST`   | `/drones/{drone_id}/cmd`   | envoi d’une commande     |

En Kubernetes, Fleet API écoute sur le port interne :

```text
8000
```

Le chart définit :

- une sonde de disponibilité sur `/ready` ;
- une sonde de vie sur `/health`.

## Simulateurs de drones

Deux implémentations liées à la simulation sont présentes dans le dépôt.

### Agent autonome

Le dossier :

```text
Application/agents/drone/
```

contient un agent Python autonome utilisant MQTT.

Il :

- s’abonne au topic de commandes de son drone ;
- vérifie la signature des commandes ;
- publie des événements ;
- publie périodiquement de la télémétrie.

### Module de simulation de Fleet API

Le fichier :

```text
Application/fleet-api/sim.py
```

contient également une implémentation de simulation MQTT.

Il utilise les mêmes familles de topics :

- `commands` ;
- `telemetry` ;
- `events`.

!!! note "Deux implémentations à distinguer"

    Le simulateur autonome situé dans `Application/agents/drone/` n’est actuellement déployé ni par Docker Compose ni par le chart Helm principal.

    Fleet API contient parallèlement son propre module de simulation. Leur articulation exacte devra être précisée dans la documentation du service après inspection détaillée de `main.py`, `manager.py` et `sim.py`.

## Frontend

Le frontend est développé avec React et Vite.

Il utilise notamment :

- Axios pour les appels HTTP ;
- la bibliothèque MQTT pour la connexion WebSocket ;
- Nginx dans l’image Docker finale.

Les valeurs locales par défaut trouvées dans le code sont :

```text
API HTTP : http://localhost:8000
MQTT WS  : ws://localhost:9001
```

Le frontend recherche les variables Vite suivantes :

```text
VITE_API_URL
VITE_MQTT_WS_URL
```

!!! warning "Configuration Helm à harmoniser"

    Le chart Helm injecte actuellement :

    ```text
    VITE_API_BASE
    VITE_MQTT_URL
    ```

    Ces noms ne correspondent pas à ceux recherchés dans le code du frontend.

    L’effet réel de ces variables doit être vérifié et la configuration devra être harmonisée avant d’être considérée comme stable.

## Déploiement Kubernetes

Le chart principal se trouve dans :

```text
Application/machina-sandbox/
```

Il génère actuellement sept ressources :

- un ConfigMap pour Mosquitto ;
- trois Deployments ;
- trois Services.

Les Deployments sont :

```text
broker
fleet-api
front
```

Les Services portent les mêmes noms.

Le chart utilise une réplique par composant dans sa configuration par défaut.

## Images Kubernetes

| Composant | Image                 | Politique      |
| --------- | --------------------- | -------------- |
| Broker    | `eclipse-mosquitto:2` | `IfNotPresent` |
| Fleet API | `fleet-api:latest`    | `Never`        |
| Frontend  | `front:latest`        | `Never`        |

Les images Fleet API et frontend doivent donc être construites localement puis chargées dans le nœud Minikube.

Cette opération est réalisée par :

```bash
make devcont-deploy
```

## Contrôles de santé Kubernetes

| Composant | Type               | Contrôle                   |
| --------- | ------------------ | -------------------------- |
| Broker    | Readiness          | connexion TCP sur `1883`   |
| Fleet API | Readiness          | requête HTTP sur `/ready`  |
| Fleet API | Liveness           | requête HTTP sur `/health` |
| Frontend  | Aucun actuellement | —                          |

!!! note "Frontend"

    Le chart ne définit actuellement aucune sonde de vie ou de disponibilité pour le frontend.

## Stockage

Fleet API utilise une base SQLite configurée avec :

```text
sqlite:///data/fleet.db
```

Dans Docker Compose, le dossier est monté depuis le dépôt.

Dans le chart Helm actuel, aucun volume persistant n’est déclaré pour Fleet API.

!!! warning "Persistance Kubernetes"

    Les données SQLite présentes dans le conteneur Fleet API peuvent être perdues lorsque le pod est remplacé.

    Une stratégie de persistance devra être ajoutée avant d’utiliser ce déploiement pour conserver durablement des données.

## Source de vérité

Pour le déploiement Kubernetes actuel, la source la plus à jour est :

```text
Application/machina-sandbox/
```

Les manifests présents dans :

```text
Application/k8s/
```

peuvent appartenir à des expérimentations ou à des versions antérieures.

Ils doivent être vérifiés avant utilisation.

## Limites actuelles

L’architecture présente encore plusieurs éléments expérimentaux :

- broker MQTT anonyme ;
- secret partagé de développement dans les valeurs Helm ;
- absence de persistance Kubernetes pour SQLite ;
- absence de sonde frontend ;
- agent autonome non intégré au chart principal ;
- variables frontend Helm à harmoniser ;
- monitoring et GitOps à vérifier séparément.

## Pages associées

- [Réseau et ports](networking.md)
- [Flux de données](data-flow.md)
- [Environnements](environments.md)
- [Broker MQTT](../services/broker-mqtt.md)
- [Fleet API](../services/fleet-api.md)
