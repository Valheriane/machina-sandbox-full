# Flux de données

Cette page décrit les flux HTTP et MQTT actuellement identifiables dans le code de **Machina Sandbox Full**.

## Vue générale

L’application utilise deux types de communication :

- HTTP pour la gestion de la flotte ;
- MQTT pour les commandes, la télémétrie et les événements.

```text
Frontend
    |
    +--> HTTP --> Fleet API
    |
    +--> MQTT WebSocket --> Broker MQTT
                                  |
                                  +--> commandes --> Drone
                                  |
                                  +<-- télémétrie -- Drone
                                  |
                                  +<-- événements --- Drone
```

## Gestion HTTP de la flotte

Le frontend utilise Axios pour communiquer avec Fleet API.

Fleet API expose actuellement les routes suivantes :

| Méthode  | Route                      |
| -------- | -------------------------- |
| `GET`    | `/health`                  |
| `GET`    | `/ready`                   |
| `POST`   | `/drones`                  |
| `GET`    | `/drones`                  |
| `GET`    | `/drones/{drone_id}`       |
| `PATCH`  | `/drones/{drone_id}`       |
| `DELETE` | `/drones/{drone_id}`       |
| `POST`   | `/drones/{drone_id}/start` |
| `POST`   | `/drones/{drone_id}/stop`  |
| `POST`   | `/drones/{drone_id}/cmd`   |

Le frontend contient notamment des appels associés à :

- la création d’un drone ;
- la liste des drones ;
- la modification d’un drone ;
- la suppression d’un drone ;
- le démarrage et l’arrêt ;
- l’envoi d’une commande.

## URL HTTP du frontend

Le code du frontend recherche :

```text
VITE_API_URL
```

Lorsque cette variable est absente, la valeur utilisée par défaut est :

```text
http://localhost:8000
```

Le service Axios est défini dans :

```text
Application/front/src/services/api.js
```

## Topics MQTT

Les topics des agents de drones suivent cette structure :

```text
{prefixe}/drone/{drone_id}/{type}
```

Le préfixe par défaut est :

```text
lab
```

Les trois topics principaux sont donc :

```text
lab/drone/{drone_id}/commands
lab/drone/{drone_id}/telemetry
lab/drone/{drone_id}/events
```

| Topic       | Producteur principal | Consommateur principal           |
| ----------- | -------------------- | -------------------------------- |
| `commands`  | Fleet API            | Drone                            |
| `telemetry` | Drone                | Frontend et futurs consommateurs |
| `events`    | Drone                | Frontend et futurs consommateurs |

## Envoi d’une commande

Le flux général d’une commande est :

```text
Utilisateur
    |
    v
Frontend
    |
    | POST /drones/{drone_id}/cmd
    v
Fleet API
    |
    | publication MQTT
    v
lab/drone/{drone_id}/commands
    |
    v
Drone
```

Fleet API construit le topic de commande à partir :

- du préfixe MQTT ;
- de l’identifiant du drone ;
- du suffixe `commands`.

## Signature des commandes

Les commandes MQTT comprennent au minimum deux éléments vérifiés par l’agent :

```text
payload
sig
```

L’agent refuse le message si :

- `payload` n’est pas un objet JSON ;
- `sig` n’est pas une chaîne ;
- la signature n’est pas valide.

La vérification est réalisée avec une signature HMAC et un secret partagé.

!!! danger "Secret partagé"

    Le secret utilisé pour signer les commandes ne doit jamais être publié dans la documentation.

    Les valeurs présentes dans les fichiers d’exemple sont uniquement destinées au développement local.

## Réception d’une commande par le drone

L’agent autonome s’abonne à :

```text
lab/drone/{drone_id}/commands
```

Lorsqu’il se connecte, il publie également un événement sur :

```text
lab/drone/{drone_id}/events
```

Le code contient notamment un événement de type :

```text
pong
```

La liste complète des commandes et des événements doit être documentée après inspection détaillée de :

```text
Application/agents/drone/drone_agent.py
Application/fleet-api/sim.py
Application/fleet-api/manager.py
```

## Publication de la télémétrie

Le drone publie périodiquement sa télémétrie sur :

```text
lab/drone/{drone_id}/telemetry
```

L’intervalle est configurable avec :

```text
PUBLISH_INTERVAL_SEC
```

Sa valeur par défaut est :

```text
1.0
```

La publication utilise actuellement le niveau de qualité de service MQTT :

```text
QoS 0
```

!!! info "QoS 0"

    Avec QoS 0, le broker et le client ne garantissent pas la livraison de chaque message.

    Ce choix est fréquent pour une télémétrie fréquente dans un environnement de simulation.

## Publication des événements

Les événements sont publiés sur :

```text
lab/drone/{drone_id}/events
```

Ils peuvent notamment signaler :

- la connexion du drone ;
- une réponse de type `pong` ;
- d’autres changements d’état définis dans le simulateur.

Les structures JSON exactes doivent être extraites du code avant d’être considérées comme un contrat stable.

## Consommation MQTT par le frontend

Le frontend utilise la bibliothèque MQTT depuis :

```text
Application/front/src/services/mqtt.js
```

Il recherche la variable :

```text
VITE_MQTT_WS_URL
```

Sa valeur par défaut est :

```text
ws://localhost:9001
```

Les composants suivants utilisent le service MQTT :

```text
MapPanel
TelemetryFeed
```

Ils peuvent ainsi recevoir des données en temps réel sans interroger continuellement Fleet API.

## Flux de télémétrie vers le navigateur

```text
Drone
    |
    | publication MQTT TCP
    v
Broker MQTT
    |
    | MQTT WebSocket
    v
Frontend
    |
    +--> TelemetryFeed
    |
    +--> MapPanel
```

## Flux des contrôles de santé

Kubernetes utilise deux routes de Fleet API.

### Santé du processus

```text
GET /health
```

Cette route est utilisée par la sonde de vie.

Elle permet à Kubernetes de déterminer si le processus doit être redémarré.

### Disponibilité

```text
GET /ready
```

Cette route est utilisée par la sonde de disponibilité.

Elle permet à Kubernetes de déterminer si le pod peut recevoir du trafic.

Le comportement détaillé de ces routes doit rester aligné avec l’implémentation de :

```text
Application/fleet-api/main.py
```

## Simulateur intégré et agent autonome

Le dépôt contient deux chemins possibles pour produire des messages de drone :

```text
Application/fleet-api/sim.py
Application/agents/drone/drone_agent.py
```

Les deux utilisent les familles de topics :

```text
commands
telemetry
events
```

L’agent autonome n’est actuellement intégré ni au fichier Docker Compose ni au chart Helm principal.

!!! warning "Architecture en évolution"

    La coexistence de deux implémentations de simulation doit être clarifiée.

    Il faudra déterminer si l’agent autonome doit remplacer la simulation interne, la compléter ou être utilisé uniquement pour certains tests.

## Contrats à stabiliser

Les éléments suivants ne doivent pas encore être considérés comme des contrats définitifs :

- structure complète des commandes ;
- structure complète de la télémétrie ;
- liste des événements ;
- règles de versionnement des messages ;
- comportement en cas d’erreur de signature ;
- niveaux de QoS selon le type de message ;
- conservation ou non des messages ;
- format des horodatages.

Ils seront documentés dans :

[Contrats de messages](../integrations/message-contracts.md)

## Pages associées

- [Vue générale](overview.md)
- [Réseau et ports](networking.md)
- [Fleet API](../services/fleet-api.md)
- [Simulateur de drones](../services/drone-simulator.md)
- [Consommer la télémétrie](../integrations/telemetry-consumer.md)
