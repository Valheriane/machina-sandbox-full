# Fleet API

Fleet API est le service backend de **Machina Sandbox Full**.

Elle fournit une API HTTP permettant de gérer une flotte de drones simulés, de démarrer ou d’arrêter leurs workers et de publier des commandes signées sur le broker MQTT.

## Emplacement

Le service se trouve dans :

```text
Application/fleet-api/
```

Les principaux fichiers sont :

| Fichier            | Rôle                                  |
| ------------------ | ------------------------------------- |
| `main.py`          | application FastAPI et routes HTTP    |
| `manager.py`       | gestion des workers et du client MQTT |
| `models.py`        | modèles SQLModel et schémas de l’API  |
| `sim.py`           | simulation intégrée des drones        |
| `config.py`        | lecture des variables d’environnement |
| `security.py`      | signature et vérification HMAC        |
| `Dockerfile`       | construction de l’image Docker        |
| `requirements.txt` | dépendances Python                    |

## Technologies

Fleet API utilise notamment :

| Technologie | Rôle                                |
| ----------- | ----------------------------------- |
| Python 3.11 | langage d’exécution                 |
| FastAPI     | API HTTP                            |
| Uvicorn     | serveur ASGI                        |
| SQLModel    | modèles et accès à SQLite           |
| Pydantic    | validation des requêtes et réponses |
| Paho MQTT   | communication avec Mosquitto        |
| SQLite      | persistance locale                  |
| HMAC-SHA256 | signature des commandes             |

L’application FastAPI est déclarée avec :

```text
Titre   : Fleet API
Version : 0.1.0
```

## Responsabilités

Fleet API assure actuellement les fonctions suivantes :

- créer et enregistrer des drones ;
- consulter la flotte ;
- modifier les paramètres d’un drone ;
- supprimer un drone ;
- démarrer un worker de simulation ;
- arrêter un worker ;
- signer une commande ;
- publier cette commande sur MQTT ;
- exposer des routes de santé et de disponibilité.

## Architecture interne

```text
Requête HTTP
    |
    v
FastAPI
    |
    +--> SQLModel --> SQLite
    |
    +--> FleetManager
             |
             +--> client MQTT principal
             |
             +--> DroneWorker
                     |
                     +--> client MQTT du drone
                     +--> thread de simulation
```

Le processus contient donc deux usages distincts de MQTT :

1. le client principal de `FleetManager`, utilisé pour publier les commandes ;
2. un client MQTT par `DroneWorker`, utilisé pour recevoir les commandes et publier la télémétrie.

## Configuration

La fonction `get_config()` centralise la majorité des variables d’environnement.

### Configuration générale

| Variable        | Valeur par défaut         | Rôle                              |
| --------------- | ------------------------- | --------------------------------- |
| `APP_ENV`       | `dev`                     | environnement logique             |
| `DATABASE_URL`  | `sqlite:///data/fleet.db` | connexion SQLite                  |
| `SHARED_SECRET` | valeur de développement   | secret HMAC                       |
| `DISABLE_MQTT`  | vide                      | désactivation facultative de MQTT |

### Configuration MQTT

| Variable       | Valeur par défaut | Rôle                 |
| -------------- | ----------------- | -------------------- |
| `MQTT_HOST`    | `localhost`       | adresse du broker    |
| `MQTT_PORT`    | `1883`            | port MQTT TCP        |
| `TOPIC_PREFIX` | `lab`             | préfixe MQTT général |

En Docker Compose, Fleet API reçoit notamment :

```text
MQTT_HOST=broker
MQTT_PORT=1883
TOPIC_PREFIX=lab
```

En Kubernetes, les mêmes informations sont fournies par le chart Helm.

## Désactivation de MQTT

MQTT peut être désactivé avec :

```text
DISABLE_MQTT=true
```

Les valeurs reconnues sont :

```text
1
true
yes
```

Dans ce mode :

- aucun client MQTT principal n’est créé ;
- `/health` reste accessible ;
- `/ready` retourne une erreur ;
- l’envoi d’une commande échoue.

Ce mode peut être utile pour certains tests HTTP ne nécessitant pas le broker.

## Connexion au broker

`FleetManager` utilise une connexion asynchrone :

```text
connect_async
```

La boucle réseau MQTT fonctionne dans un thread en arrière-plan.

Une reconnexion progressive est configurée :

```text
1 seconde
2 secondes
4 secondes
...
30 secondes maximum
```

Cette stratégie permet à Fleet API de démarrer même si le broker n’est pas encore totalement disponible.

## Santé et disponibilité

Fleet API distingue la santé du processus HTTP de sa disponibilité MQTT.

### `GET /health`

Cette route retourne toujours une réponse HTTP normale tant que le processus fonctionne.

Exemple :

```json
{
  "status": "ok",
  "mqtt_connected": true
}
```

Lorsque MQTT est indisponible :

```json
{
  "status": "ok",
  "mqtt_connected": false
}
```

Cette route est utilisée comme sonde de vie Kubernetes.

### `GET /ready`

Cette route vérifie la connexion réelle au broker.

Lorsque MQTT est disponible :

```json
{
  "status": "ready",
  "mqtt": "connected"
}
```

Lorsque MQTT est indisponible, la route retourne :

```text
HTTP 503
```

avec le détail :

```text
MQTT not connected
```

Cette route est utilisée comme sonde de disponibilité Kubernetes.

!!! info "Différence importante"

    `/health` répond à la question : « Le processus Fleet API fonctionne-t-il ? »

    `/ready` répond à la question : « Fleet API est-elle prête à communiquer avec MQTT ? »

## Routes HTTP

| Méthode  | Route                      | Rôle                      |
| -------- | -------------------------- | ------------------------- |
| `GET`    | `/health`                  | santé du processus        |
| `GET`    | `/ready`                   | disponibilité MQTT        |
| `POST`   | `/drones`                  | créer un drone            |
| `GET`    | `/drones`                  | lister les drones         |
| `GET`    | `/drones/{drone_id}`       | consulter un drone        |
| `PATCH`  | `/drones/{drone_id}`       | modifier un drone         |
| `DELETE` | `/drones/{drone_id}`       | supprimer un drone        |
| `POST`   | `/drones/{drone_id}/start` | démarrer sa simulation    |
| `POST`   | `/drones/{drone_id}/stop`  | arrêter sa simulation     |
| `POST`   | `/drones/{drone_id}/cmd`   | publier une commande MQTT |

## Modèle d’un drone

Le modèle SQLModel contient actuellement :

| Champ                  | Type   | Valeur par défaut |
| ---------------------- | ------ | ----------------: |
| `id`                   | chaîne |       obligatoire |
| `topic_prefix`         | chaîne |             `lab` |
| `start_lat`            | nombre |         `48.8566` |
| `start_lon`            | nombre |          `2.3522` |
| `start_alt`            | nombre |             `0.0` |
| `publish_interval_sec` | nombre |             `1.0` |
| `cruise_speed_mps`     | nombre |             `8.0` |
| `battery_drain`        | nombre |           `0.005` |
| `heading_noise`        | nombre |             `0.0` |
| `status`               | chaîne |         `stopped` |

Le champ `id` constitue la clé primaire.

Exemple :

```json
{
  "id": "drone-001",
  "topic_prefix": "lab",
  "start_lat": 48.8566,
  "start_lon": 2.3522,
  "start_alt": 0,
  "publish_interval_sec": 1,
  "cruise_speed_mps": 8,
  "battery_drain": 0.005,
  "heading_noise": 0
}
```

## Création d’un drone

### Requête

```http
POST /drones
```

Exemple de corps :

```json
{
  "id": "drone-001",
  "topic_prefix": "lab",
  "start_lat": 48.8566,
  "start_lon": 2.3522,
  "start_alt": 0,
  "publish_interval_sec": 1,
  "cruise_speed_mps": 8,
  "battery_drain": 0.005,
  "heading_noise": 0
}
```

Un drone nouvellement créé reçoit le statut :

```text
stopped
```

Si l’identifiant existe déjà, l’API retourne :

```text
HTTP 400
Drone already exists
```

La création en base ne démarre pas automatiquement la simulation.

## Consultation de la flotte

### Liste

```http
GET /drones
```

### Drone unique

```http
GET /drones/{drone_id}
```

Si le drone n’existe pas :

```text
HTTP 404
Not found
```

Le statut retourné est recalculé selon l’état du worker présent en mémoire :

```text
running
stopped
```

Il ne représente pas directement l’état physique simulé, comme `flying` ou `landing`.

## Modification

```http
PATCH /drones/{drone_id}
```

Seuls les champs fournis dans la requête sont modifiés.

Exemple :

```json
{
  "cruise_speed_mps": 12,
  "heading_noise": 2
}
```

!!! warning "Worker déjà actif"

    La modification met à jour la base de données.

    Un worker déjà démarré conserve cependant les paramètres avec lesquels il a été créé.

    Pour appliquer les nouveaux paramètres, il peut être nécessaire d’arrêter puis de redémarrer le drone.

## Suppression

```http
DELETE /drones/{drone_id}
```

Avant la suppression en base, Fleet API tente d’arrêter le worker correspondant.

Réponse :

```json
{
  "ok": true
}
```

Si le drone n’existe pas, l’API retourne `404`.

## Démarrage d’un drone

```http
POST /drones/{drone_id}/start
```

Fleet API :

1. charge le drone depuis SQLite ;
2. crée un `DroneWorker` s’il n’existe pas ;
3. démarre le thread du worker ;
4. connecte ce worker au broker MQTT.

Réponse :

```json
{
  "ok": true,
  "status": "running"
}
```

Si le worker est déjà actif, aucun second thread n’est créé.

## Arrêt d’un drone

```http
POST /drones/{drone_id}/stop
```

Réponse :

```json
{
  "ok": true,
  "status": "stopped"
}
```

Le worker :

- quitte sa boucle ;
- arrête sa boucle réseau MQTT ;
- se déconnecte du broker.

!!! note "Identifiant inconnu"

    La route d’arrêt ne vérifie actuellement pas l’existence du drone dans SQLite.

    Elle peut donc retourner un succès même lorsqu’aucun worker ne correspond à l’identifiant demandé.

## Envoi d’une commande

```http
POST /drones/{drone_id}/cmd
```

Exemple :

```json
{
  "cmd": "goto",
  "args": {
    "lat": 48.857,
    "lon": 2.36,
    "alt": 20
  }
}
```

Les commandes attendues par le modèle sont :

```text
ping
takeoff
land
goto
rth
```

Fleet API construit ensuite un payload :

```json
{
  "cmd": "goto",
  "args": {
    "lat": 48.857,
    "lon": 2.36,
    "alt": 20
  }
}
```

## Signature de la commande

Le payload est signé avec :

```text
HMAC-SHA256
```

L’enveloppe MQTT devient :

```json
{
  "sig": "signature-hmac",
  "payload": {
    "cmd": "goto",
    "args": {
      "lat": 48.857,
      "lon": 2.36,
      "alt": 20
    }
  }
}
```

La publication est effectuée sur :

```text
{topic_prefix}/drone/{drone_id}/commands
```

Exemple :

```text
lab/drone/drone-001/commands
```

La publication utilise actuellement :

```text
QoS 0
```

## Attente de MQTT

Avant de publier une commande, Fleet API attend jusqu’à :

```text
5 secondes
```

que le client MQTT principal soit connecté.

Si la connexion n’est pas disponible, l’API retourne :

```text
HTTP 503
MQTT temporarily unavailable
```

## Anomalie actuelle de la réponse `/cmd`

Dans le code audité, la réponse prévue est :

```json
{
  "ok": true,
  "topic": "lab/drone/drone-001/commands",
  "envelope": {}
}
```

Cependant, le `return` correspondant est placé dans le bloc `except`, après une instruction `raise`.

Il est donc inaccessible.

En cas de publication réussie, la fonction atteint actuellement sa fin sans valeur de retour explicite et FastAPI peut répondre :

```json
null
```

!!! warning "Correction nécessaire"

    Le `return` doit être replacé après le bloc `try` / `except`.

    Tant que cette correction n’est pas réalisée, il ne faut pas documenter la réponse de succès comme totalement opérationnelle.

## Simulation intégrée

Fleet API utilise `DroneWorker` pour simuler chaque drone dans un thread dédié.

Chaque worker possède :

- un client MQTT ;
- un état physique simulé ;
- un waypoint éventuel ;
- une boucle de publication ;
- sa propre configuration dynamique.

Le worker :

1. se connecte au broker ;
2. s’abonne au topic de commandes ;
3. publie un événement de connexion ;
4. publie périodiquement la télémétrie ;
5. applique les commandes reçues.

Les limites détaillées de la simulation sont documentées dans :

[Simulateur de drones](drone-simulator.md)

## Base de données

Fleet API utilise SQLite par défaut :

```text
sqlite:///data/fleet.db
```

SQLModel crée automatiquement les tables lors du premier accès au moteur.

## Persistance avec Docker Compose

Docker Compose monte :

```text
Application/fleet-api/data/
```

dans :

```text
/app/data
```

La base peut donc rester disponible après l’arrêt du conteneur.

## Persistance avec Kubernetes

Le chart Helm ne définit actuellement aucun volume persistant pour Fleet API.

La base SQLite est stockée dans le système de fichiers du pod.

!!! warning "Perte possible des données"

    Une recréation ou un remplacement du pod peut supprimer la base SQLite présente dans le conteneur.

    Un PersistentVolumeClaim ou une base externe sera nécessaire pour conserver durablement les données.

## CORS

La configuration CORS réellement utilisée dans `main.py` lit :

```text
CORS_ORIGINS
```

La valeur par défaut est :

```text
http://localhost:8086,http://127.0.0.1:8086
```

Les origines sont séparées par des virgules.

Docker Compose transmet :

```text
MACHINA_CORS_ORIGINS
```

vers la variable interne :

```text
CORS_ORIGINS
```

Lors du déploiement Minikube, le Makefile calcule l’adresse du frontend et la transmet au chart Helm.

## Deux configurations CORS présentes

`config.py` définit également une logique basée sur :

```text
APP_ENV
CORS_ALLOWED_ORIGINS
```

Elle prévoit :

- une expression régulière pour localhost en développement ;
- une liste stricte en production.

Cependant, cette configuration n’est actuellement pas utilisée par le middleware actif de `main.py`.

!!! warning "Configuration à harmoniser"

    Deux mécanismes CORS coexistent dans le code :

    - `CORS_ORIGINS` directement dans `main.py` ;
    - `APP_ENV` et `CORS_ALLOWED_ORIGINS` dans `config.py`.

    Une seule source de configuration devrait être conservée afin d’éviter les comportements contradictoires.

## Image Docker

L’image est basée sur :

```text
python:3.11-slim
```

Le serveur est lancé avec :

```text
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Fleet API écoute donc sur :

```text
0.0.0.0:8000
```

!!! warning "Mode reload"

    L’option `--reload` est adaptée au développement.

    Elle n’est généralement pas souhaitable dans une image destinée à un environnement stable ou de production.

## Docker Compose

Le service Compose se nomme :

```text
fleet-api
```

Il dépend du service :

```text
broker
```

Le port est publié avec :

```text
MACHINA_API_PORT
```

La valeur par défaut est :

```text
8000
```

Démarrage :

```bash
make compose-up
```

État :

```bash
make compose-status
```

Logs ciblés :

```bash
docker compose \
  --project-directory Application \
  -f Application/docker-compose.yml \
  logs --follow --tail=100 fleet-api
```

## Kubernetes

Le chart crée :

- un Deployment `fleet-api` ;
- un Service `fleet-api`.

### Ports

| Port interne | NodePort |
| -----------: | -------: |
|       `8000` |  `30800` |

### Image

```text
fleet-api:latest
```

La politique de téléchargement est :

```text
Never
```

L’image doit donc être construite puis chargée dans Minikube.

Cette opération est réalisée par :

```bash
make devcont-deploy
```

### Probes

| Probe     | Route     | Rôle               |
| --------- | --------- | ------------------ |
| Readiness | `/ready`  | disponibilité MQTT |
| Liveness  | `/health` | santé du processus |

## Tests

Le dossier contient actuellement un test pour la route :

```text
/health
```

Les dépendances de test incluent :

- `pytest` ;
- `pytest-asyncio` ;
- `httpx`.

La couverture de test reste limitée.

Les routes CRUD, MQTT et les erreurs ne disposent pas encore d’une couverture complète visible dans le dépôt audité.

## Limites actuelles

Fleet API présente notamment les limites suivantes :

- SQLite non persistante dans Kubernetes ;
- dépendances Python non verrouillées ;
- serveur Docker lancé avec `--reload` ;
- réponse de succès de `/cmd` incorrectement placée ;
- deux mécanismes CORS concurrents ;
- route `/stop` permissive pour les identifiants inconnus ;
- absence de gestion centralisée des erreurs de workers ;
- simulation exécutée dans le même processus que l’API ;
- absence de distinction entre drones aériens, terrestres et marins ;
- absence de système d’authentification HTTP ;
- secret HMAC de développement présent comme valeur par défaut.

## Évolutions possibles

Les améliorations pourront être introduites progressivement :

1. corriger la réponse de `/cmd` ;
2. harmoniser la configuration CORS ;
3. retirer `--reload` des images stables ;
4. verrouiller les versions Python ;
5. ajouter des tests CRUD et MQTT ;
6. ajouter une persistance Kubernetes ;
7. isoler les workers de simulation ;
8. ajouter des types de véhicules ;
9. enrichir les erreurs et les événements ;
10. introduire une authentification et des autorisations.

## Pages associées

- [Simulateur de drones](drone-simulator.md)
- [Broker MQTT](broker-mqtt.md)
- [Frontend](frontend.md)
- [Flux de données](../architecture/data-flow.md)
- [Contrats de messages](../integrations/message-contracts.md)
