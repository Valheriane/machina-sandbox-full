# Consommer la télémétrie MQTT

Cette page explique comment intégrer un service capable de recevoir la télémétrie publiée par les drones simulés de **Machina Sandbox Full**.

Un consommateur de télémétrie peut notamment servir à :

- enregistrer les positions GPS ;
- traiter des données IoT ;
- détecter des anomalies ;
- alimenter une base de données ;
- produire des métriques ;
- préparer des traitements différés ;
- transmettre les données à un autre système.

!!! info "Fonctionnalité d’intégration"

    Le projet ne contient pas encore de service backend dédié à la consommation et au stockage de la télémétrie.

    Le frontend consomme déjà certains messages MQTT dans le navigateur, mais les exemples de cette page décrivent une future intégration côté serveur.

## Flux actuel

Le simulateur publie actuellement la télémétrie sur :

```text
{topic_prefix}/drone/{drone_id}/telemetry
```

Avec les valeurs par défaut :

```text
lab/drone/drone-001/telemetry
```

Pour recevoir la télémétrie de tous les drones utilisant le préfixe `lab`, un consommateur peut s’abonner à :

```text
lab/drone/+/telemetry
```

Le caractère `+` représente exactement un niveau variable du topic.

L’abonnement reçoit donc, par exemple :

```text
lab/drone/drone-001/telemetry
lab/drone/drone-002/telemetry
lab/drone/vehicle-alpha/telemetry
```

## Architecture générale

```text
Simulateurs de drones
          |
          | publication MQTT
          v
     Broker Mosquitto
          |
          +--> Frontend
          |
          +--> Consommateur de télémétrie
          |         |
          |         +--> validation
          |         +--> transformation
          |         +--> stockage
          |         +--> métriques
          |
          +--> Futurs consommateurs spécialisés
```

Le broker distribue un même message à chaque client abonné au topic correspondant.

Les consommateurs peuvent donc travailler indépendamment les uns des autres.

## Payload actuellement publié

Le simulateur produit actuellement un message de la forme :

```json
{
  "drone_id": "drone-001",
  "ts": 1710000000.0,
  "position": {
    "lat": 48.8566,
    "lon": 2.3522,
    "alt": 20.0
  },
  "speed_mps": 8.0,
  "battery_pct": 99.5,
  "status": "flying",
  "heading_deg": 90.0
}
```

## Champs disponibles

| Champ          | Type   | Description                   |
| -------------- | ------ | ----------------------------- |
| `drone_id`     | chaîne | identifiant du véhicule       |
| `ts`           | nombre | horodatage Unix en secondes   |
| `position.lat` | nombre | latitude                      |
| `position.lon` | nombre | longitude                     |
| `position.alt` | nombre | altitude simulée              |
| `speed_mps`    | nombre | vitesse en mètres par seconde |
| `battery_pct`  | nombre | niveau de batterie            |
| `status`       | chaîne | état physique simulé          |
| `heading_deg`  | nombre | cap entre 0 et 360 degrés     |

!!! warning "Contrat encore expérimental"

    Le message ne contient actuellement :

    - aucun numéro de version ;
    - aucun identifiant unique de message ;
    - aucune unité explicite pour l’altitude ;
    - aucun type de véhicule ;
    - aucune information sur la précision des capteurs.

    Un consommateur doit donc rester tolérant aux évolutions futures du payload.

## QoS actuel

La télémétrie est publiée avec :

```text
QoS 0
```

Cela signifie que les messages sont transmis au mieux, sans garantie de livraison.

Ce comportement est acceptable pour une télémétrie fréquente dans un bac à sable, car le message suivant remplace rapidement l’état précédent.

!!! warning "Archivage exhaustif"

    Un consommateur nécessitant un historique complet ne doit pas supposer que chaque message sera reçu.

    Il faudra étudier :

    - QoS 1 ;
    - la reconnexion ;
    - la persistance de session ;
    - les doublons ;
    - la mise en mémoire tampon ;
    - la reprise après interruption.

## Exemple de consommateur Python

L’exemple suivant illustre un futur service Python indépendant.

Il n’existe pas encore dans le dépôt.

### Arborescence proposée

```text
Application/
└── telemetry-consumer/
    ├── consumer.py
    ├── requirements.txt
    └── Dockerfile
```

Le nom et l’emplacement devront être validés avant intégration officielle.

### Dépendance

Exemple de `requirements.txt` :

```text
paho-mqtt>=2,<3
```

Verrouiller plus précisément la version lors de l’intégration définitive.

### Exemple `consumer.py`

```python
import json
import os
import signal
import sys
from typing import Any

import paho.mqtt.client as mqtt


MQTT_HOST = os.getenv("MQTT_HOST", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
MQTT_TOPIC = os.getenv(
    "MQTT_TOPIC",
    "lab/drone/+/telemetry",
)
MQTT_CLIENT_ID = os.getenv(
    "MQTT_CLIENT_ID",
    "machina-telemetry-consumer",
)

_running = True


def validate_telemetry(data: Any) -> dict:
    if not isinstance(data, dict):
        raise ValueError("Le payload doit être un objet JSON.")

    required_fields = {
        "drone_id",
        "ts",
        "position",
        "speed_mps",
        "battery_pct",
        "status",
        "heading_deg",
    }

    missing = required_fields.difference(data)
    if missing:
        raise ValueError(
            f"Champs obligatoires absents : {sorted(missing)}"
        )

    position = data["position"]
    if not isinstance(position, dict):
        raise ValueError(
            "Le champ position doit être un objet."
        )

    for coordinate in ("lat", "lon", "alt"):
        if coordinate not in position:
            raise ValueError(
                f"Coordonnée absente : position.{coordinate}"
            )

    return data


def on_connect(
    client: mqtt.Client,
    userdata: object,
    flags: mqtt.ConnectFlags,
    reason_code: mqtt.ReasonCode,
    properties: mqtt.Properties | None,
) -> None:
    if reason_code.is_failure:
        print(
            f"[MQTT] Connexion refusée : {reason_code}",
            flush=True,
        )
        return

    print(
        f"[MQTT] Connecté à {MQTT_HOST}:{MQTT_PORT}",
        flush=True,
    )

    client.subscribe(MQTT_TOPIC, qos=0)

    print(
        f"[MQTT] Abonnement : {MQTT_TOPIC}",
        flush=True,
    )


def on_message(
    client: mqtt.Client,
    userdata: object,
    message: mqtt.MQTTMessage,
) -> None:
    try:
        raw_payload = message.payload.decode("utf-8")
        decoded = json.loads(raw_payload)
        telemetry = validate_telemetry(decoded)
    except UnicodeDecodeError as exc:
        print(
            f"[ERREUR] Encodage invalide sur "
            f"{message.topic} : {exc}",
            flush=True,
        )
        return
    except json.JSONDecodeError as exc:
        print(
            f"[ERREUR] JSON invalide sur "
            f"{message.topic} : {exc}",
            flush=True,
        )
        return
    except ValueError as exc:
        print(
            f"[ERREUR] Télémétrie invalide sur "
            f"{message.topic} : {exc}",
            flush=True,
        )
        return

    print(
        json.dumps(
            {
                "topic": message.topic,
                "telemetry": telemetry,
            },
            ensure_ascii=False,
        ),
        flush=True,
    )


def stop(
    signum: int,
    frame: object,
) -> None:
    global _running
    _running = False


def main() -> int:
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    client = mqtt.Client(
        callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
        client_id=MQTT_CLIENT_ID,
    )

    client.reconnect_delay_set(
        min_delay=1,
        max_delay=30,
    )

    client.on_connect = on_connect
    client.on_message = on_message

    try:
        client.connect(
            MQTT_HOST,
            MQTT_PORT,
            keepalive=30,
        )
        client.loop_start()

        while _running:
            signal.pause()

    except KeyboardInterrupt:
        pass
    except OSError as exc:
        print(
            f"[ERREUR] Connexion MQTT impossible : {exc}",
            file=sys.stderr,
            flush=True,
        )
        return 1
    finally:
        client.disconnect()
        client.loop_stop()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

!!! note "Exemple à adapter"

    Cet exemple montre une structure possible pour un futur service.

    Il n’est pas encore intégré à Docker Compose, Helm, la CI ou au Makefile du projet.

## Variables de configuration proposées

| Variable         | Valeur par défaut            | Rôle              |
| ---------------- | ---------------------------- | ----------------- |
| `MQTT_HOST`      | `localhost`                  | adresse du broker |
| `MQTT_PORT`      | `1883`                       | port MQTT TCP     |
| `MQTT_TOPIC`     | `lab/drone/+/telemetry`      | abonnement        |
| `MQTT_CLIENT_ID` | `machina-telemetry-consumer` | identifiant MQTT  |

En Docker Compose, l’adresse du broker serait :

```text
broker
```

La configuration deviendrait donc :

```text
MQTT_HOST=broker
MQTT_PORT=1883
```

Dans Kubernetes, le Service porte également le nom :

```text
broker
```

Un pod placé dans le même namespace pourrait donc utiliser :

```text
broker:1883
```

## Validation des messages

Un consommateur ne doit pas supposer que tous les messages sont valides.

Il doit au minimum vérifier :

1. que le payload est encodé en UTF-8 ;
2. qu’il contient du JSON valide ;
3. que le résultat est un objet ;
4. que les champs nécessaires sont présents ;
5. que les types correspondent ;
6. que les coordonnées sont plausibles ;
7. que le niveau de batterie reste dans une plage attendue ;
8. que le statut est reconnu.

## Validations possibles

### Batterie

```text
0 <= battery_pct <= 100
```

### Latitude

```text
-90 <= lat <= 90
```

### Longitude

```text
-180 <= lon <= 180
```

### Cap

```text
0 <= heading_deg < 360
```

### Vitesse

```text
speed_mps >= 0
```

### Horodatage

Le consommateur peut vérifier que l’horodatage :

- n’est pas trop ancien ;
- n’est pas excessivement dans le futur ;
- peut être converti en date valide.

!!! warning "Simulation et validation"

    Une validation trop stricte peut rejeter les futures simulations de panne ou de capteur défectueux.

    Il faudra distinguer :

    - un message techniquement invalide ;
    - une mesure physiquement inhabituelle ;
    - une anomalie volontairement simulée.

## Extraire l’identifiant depuis le topic

L’identifiant est présent à la fois :

- dans le topic ;
- dans le payload.

Exemple :

```text
Topic   : lab/drone/drone-001/telemetry
Payload : "drone_id": "drone-001"
```

Un consommateur peut comparer les deux valeurs.

Si elles diffèrent, le message peut être :

- rejeté ;
- signalé ;
- placé dans une file d’erreur.

Exemple conceptuel :

```python
parts = message.topic.split("/")
topic_drone_id = parts[2]

if topic_drone_id != telemetry["drone_id"]:
    raise ValueError(
        "L’identifiant du topic ne correspond pas au payload."
    )
```

## Ne pas bloquer la boucle MQTT

Le callback `on_message` doit rester rapide.

Il est déconseillé d’y exécuter directement :

- une opération longue ;
- un appel HTTP lent ;
- une grosse transformation ;
- une transaction de base complexe ;
- un traitement d’image ;
- une tâche de plusieurs secondes.

Une architecture plus robuste utilise une file interne :

```text
Callback MQTT
     |
     v
File en mémoire
     |
     v
Worker de traitement
     |
     v
Stockage ou service externe
```

Le callback valide rapidement le message puis le place dans la file.

Un ou plusieurs workers réalisent ensuite le traitement.

## Gestion de la pression

La fréquence par défaut est d’un message par seconde et par drone.

Avec plusieurs drones, le volume augmente rapidement.

| Drones | Messages par seconde | Messages par heure |
| -----: | -------------------: | -----------------: |
|      1 |                    1 |              3 600 |
|     10 |                   10 |             36 000 |
|    100 |                  100 |            360 000 |
|  1 000 |                1 000 |          3 600 000 |

Un futur consommateur doit définir :

- une taille maximale de file ;
- une stratégie lorsque la file est pleine ;
- des délais de traitement ;
- des métriques de retard ;
- une politique de rejet ou d’échantillonnage.

## Stratégies de stockage

Plusieurs formes de stockage peuvent être expérimentées.

### SQLite

Adapté pour :

- un prototype local ;
- un petit volume ;
- un seul processus d’écriture.

Limites :

- concurrence limitée ;
- montée en charge réduite ;
- partage difficile entre plusieurs instances.

### PostgreSQL

Adapté pour :

- les informations structurées ;
- les relations entre véhicules et missions ;
- les requêtes métier ;
- une persistance plus robuste.

### Base temporelle

Une base orientée séries temporelles peut faciliter :

- les mesures fréquentes ;
- les agrégations par période ;
- les graphiques ;
- les politiques de rétention.

### Stockage de fichiers

Des fichiers JSON Lines ou Parquet peuvent être utiles pour :

- archiver les messages ;
- rejouer un scénario ;
- préparer des analyses ;
- alimenter des traitements par lot.

!!! info "Aucun choix officiel"

    Le projet ne possède pas encore de stockage dédié à la télémétrie.

    Le choix doit dépendre de l’expérience technologique recherchée.

## Consommateur GPS

Un consommateur GPS peut utiliser les champs :

```text
position.lat
position.lon
position.alt
speed_mps
heading_deg
```

Traitements possibles :

- stockage des positions ;
- calcul de trajectoire ;
- calcul de distance ;
- détection de sortie de zone ;
- affichage cartographique ;
- génération de traces ;
- détection de position incohérente.

Avec le contrat actuel, il doit s’abonner à :

```text
lab/drone/+/telemetry
```

puis extraire les champs GPS du payload complet.

## Consommateur IoT

Un consommateur IoT pourrait traiter :

- batterie ;
- température future ;
- humidité future ;
- pression future ;
- capteurs embarqués ;
- état des moteurs ;
- charge utile.

Avec le contrat actuel, seule la batterie est réellement présente parmi ces exemples.

Les autres mesures ne sont pas encore implémentées.

## Séparation future des topics

Une évolution prévue consiste à publier plusieurs sous-types.

### GPS

```text
lab/drone/{drone_id}/telemetry/gps
```

Abonnement global :

```text
lab/drone/+/telemetry/gps
```

### IoT

```text
lab/drone/{drone_id}/telemetry/iot
```

Abonnement global :

```text
lab/drone/+/telemetry/iot
```

### Énergie

```text
lab/drone/{drone_id}/telemetry/energy
```

### Navigation

```text
lab/drone/{drone_id}/telemetry/navigation
```

!!! warning "Non implémenté"

    Ces topics spécialisés sont seulement envisagés.

    Le topic confirmé dans le code reste :

    ```text
    lab/drone/{drone_id}/telemetry
    ```

## Topic large avec `#`

Pour recevoir tous les sous-topics futurs de télémétrie :

```text
lab/drone/+/telemetry/#
```

Le caractère `#` représente tous les niveaux restants.

Il recevrait par exemple :

```text
lab/drone/drone-001/telemetry/gps
lab/drone/drone-001/telemetry/iot
lab/drone/drone-001/telemetry/energy
```

Il ne reçoit pas nécessairement le topic parent sans sous-niveau selon la structure retenue et les abonnements utilisés. Pour couvrir l’ancien et le futur contrat, un consommateur peut temporairement s’abonner aux deux formes :

```text
lab/drone/+/telemetry
lab/drone/+/telemetry/#
```

Cette coexistence devra rester temporaire pendant une migration.

## Plusieurs consommateurs indépendants

MQTT permet à plusieurs services de recevoir le même message.

Exemple :

```text
lab/drone/+/telemetry
    |
    +--> affichage frontend
    +--> stockage brut
    +--> alertes batterie
    +--> traitement GPS
```

Chaque client doit utiliser un identifiant MQTT distinct.

Exemples :

```text
machina-telemetry-archive
machina-gps-consumer
machina-energy-alerts
```

## Répartition entre plusieurs instances

Deux instances utilisant des identifiants distincts reçoivent chacune les messages correspondant à leur abonnement.

Ce comportement est adapté à des traitements différents.

Pour répartir une même charge entre plusieurs workers, il faut concevoir un mécanisme adapté :

- abonnements partagés si le broker les prend en charge ;
- file de messages externe ;
- partitionnement par drone ;
- service unique avec plusieurs workers internes.

Cette stratégie n’est pas encore définie dans le projet.

## Authentification MQTT

Le broker autorise actuellement les connexions anonymes.

Un futur consommateur pourra prévoir :

```text
MQTT_USERNAME
MQTT_PASSWORD
```

puis configurer le client :

```python
client.username_pw_set(
    username,
    password,
)
```

Cette configuration ne sera utile que lorsque Mosquitto utilisera :

```text
allow_anonymous false
```

et un fichier de mots de passe actif.

## TLS

Les connexions actuelles utilisent :

```text
mqtt://
ws://
```

Elles ne sont pas chiffrées.

Un environnement exposé devrait étudier :

```text
mqtts://
wss://
```

avec :

- certificats ;
- validation du serveur ;
- rotation des secrets ;
- contrôle d’accès par topic.

## Journalisation recommandée

Un consommateur doit journaliser au minimum :

- la connexion au broker ;
- les reconnexions ;
- le topic d’abonnement ;
- le nombre de messages reçus ;
- les messages invalides ;
- les erreurs de stockage ;
- la taille de la file interne ;
- le temps de traitement.

Il ne doit pas journaliser :

- les mots de passe MQTT ;
- les secrets ;
- des données sensibles non nécessaires ;
- des payloads complets sans politique de rétention.

## Métriques recommandées

Exemples de métriques futures :

```text
telemetry_messages_received_total
telemetry_messages_invalid_total
telemetry_messages_processed_total
telemetry_processing_errors_total
telemetry_queue_size
telemetry_processing_duration_seconds
telemetry_last_message_timestamp
```

Des labels possibles :

```text
consumer
topic
drone_id
status
```

!!! warning "Cardinalité"

    Utiliser `drone_id` comme label de métrique peut produire un grand nombre de séries lorsque la flotte augmente.

    La cardinalité devra être surveillée.

## Gestion des erreurs

Un consommateur peut distinguer plusieurs catégories.

| Erreur                | Action possible                          |
| --------------------- | ---------------------------------------- |
| JSON invalide         | journaliser et ignorer                   |
| champ absent          | placer en erreur de validation           |
| valeur impossible     | signaler une anomalie                    |
| stockage indisponible | réessayer ou mettre en file              |
| broker déconnecté     | laisser le client se reconnecter         |
| format inconnu        | conserver éventuellement le message brut |

Une future file d’erreur pourrait enregistrer :

```json
{
  "topic": "lab/drone/drone-001/telemetry",
  "received_at": "2026-08-04T12:00:00Z",
  "error": "Champ position absent",
  "raw_payload": "{}"
}
```

La conservation du payload brut doit respecter les règles de sécurité et de rétention.

## Idempotence et doublons

Le contrat actuel ne contient pas de :

```text
message_id
```

Un consommateur ne peut donc pas identifier de manière fiable deux livraisons du même message.

Une future enveloppe devrait inclure :

- un identifiant unique ;
- un horodatage ;
- une version ;
- éventuellement un numéro de séquence.

Cela faciliterait :

- la déduplication ;
- le tri ;
- la détection de pertes ;
- le rejeu.

## Retard et messages désordonnés

Les messages peuvent être reçus :

- avec du retard ;
- après une reconnexion ;
- dans un ordre inattendu ;
- avec des horodatages proches.

Un service stockant des trajectoires doit utiliser l’horodatage du message plutôt que seulement son heure de réception.

Il peut conserver les deux valeurs :

```text
event_timestamp
received_timestamp
```

## Tests recommandés

Un futur consommateur devrait être testé avec :

1. un message valide ;
2. un JSON invalide ;
3. un payload incomplet ;
4. une latitude invalide ;
5. une batterie hors limites ;
6. un statut inconnu ;
7. une déconnexion du broker ;
8. une reconnexion ;
9. une erreur de stockage ;
10. plusieurs drones simultanés.

## Test manuel avec Mosquitto

Lorsque les outils clients Mosquitto sont disponibles, un abonnement peut être testé avec :

```bash
mosquitto_sub \
  --host localhost \
  --port 1883 \
  --topic 'lab/drone/+/telemetry' \
  --verbose
```

Exemple de publication manuelle :

```bash
mosquitto_pub \
  --host localhost \
  --port 1883 \
  --topic 'lab/drone/drone-test/telemetry' \
  --message '{
    "drone_id": "drone-test",
    "ts": 1710000000,
    "position": {
      "lat": 48.8566,
      "lon": 2.3522,
      "alt": 10
    },
    "speed_mps": 2,
    "battery_pct": 80,
    "status": "flying",
    "heading_deg": 90
  }'
```

!!! note "Outils facultatifs"

    `mosquitto_sub` et `mosquitto_pub` ne sont pas actuellement garantis dans le Dev Container.

    Leur installation éventuelle devra être documentée séparément.

## Intégration Docker Compose

Un futur service pourrait être ajouté à :

```text
Application/docker-compose.yml
```

Exemple conceptuel :

```yaml
telemetry-consumer:
  build:
    context: ./telemetry-consumer

  environment:
    MQTT_HOST: broker
    MQTT_PORT: 1883
    MQTT_TOPIC: lab/drone/+/telemetry
    MQTT_CLIENT_ID: machina-telemetry-consumer

  depends_on:
    - broker

  networks:
    - iotnet
```

!!! warning "Exemple non présent dans le dépôt"

    Ce service n’est pas encore déclaré dans le fichier Compose actuel.

    Toute intégration devra être validée avec :

    ```bash
    make compose-config
    ```

## Intégration Kubernetes

Un futur déploiement Kubernetes pourrait contenir :

- un Deployment ;
- une ConfigMap ;
- un Secret si une authentification est activée ;
- éventuellement un Service si le consommateur expose une API ou des métriques ;
- une sonde de santé ;
- une sonde de disponibilité.

Un consommateur qui reçoit uniquement MQTT n’a pas obligatoirement besoin d’un Service Kubernetes.

Il peut cependant exposer un port HTTP interne pour :

```text
/health
/ready
/metrics
```

## Santé d’un consommateur

Une future sonde `/health` pourrait vérifier :

- que le processus fonctionne ;
- que la boucle de traitement n’est pas bloquée.

Une sonde `/ready` pourrait vérifier :

- la connexion MQTT ;
- la connexion au stockage ;
- la capacité de la file interne.

Il faut éviter qu’une panne temporaire du broker provoque des redémarrages continus inutiles.

## Place d’Airflow

Airflow est adapté à des traitements planifiés ou par lots.

Il n’est généralement pas utilisé comme consommateur MQTT temps réel principal.

Une architecture possible serait :

```text
Broker MQTT
    |
    v
Consommateur temps réel
    |
    v
Stockage
    |
    v
Airflow
    |
    +--> agrégation quotidienne
    +--> nettoyage
    +--> rapport
    +--> export
```

Dans cette architecture :

- le consommateur enregistre les messages au fil de l’eau ;
- Airflow traite ensuite les données stockées selon un calendrier.

Airflow pourra être étudié dans :

[Airflow](airflow.md)

## Étapes d’intégration recommandées

Pour ajouter un consommateur au projet :

1. définir son objectif précis ;
2. choisir les topics ;
3. stabiliser les champs nécessaires ;
4. créer son dossier applicatif ;
5. verrouiller ses dépendances ;
6. ajouter des tests ;
7. l’intégrer à Docker Compose ;
8. valider avec `make compose-config` ;
9. ajouter son déploiement Helm si nécessaire ;
10. ajouter les probes et métriques ;
11. documenter les limites ;
12. mettre à jour les contrats de messages.

## Première expérimentation conseillée

Une première version simple pourrait :

1. s’abonner à `lab/drone/+/telemetry` ;
2. valider le JSON ;
3. afficher les données reçues ;
4. compter les messages par drone ;
5. enregistrer temporairement les messages dans un fichier JSON Lines.

Cette version permettrait de tester le flux avant de choisir une base de données ou Airflow.

## État actuel et futur

| Fonctionnalité                 | État                                      |
| ------------------------------ | ----------------------------------------- |
| Publication de télémétrie MQTT | opérationnelle dans le simulateur intégré |
| Consommation dans le frontend  | présente                                  |
| Consommateur backend dédié     | non implémenté                            |
| Stockage de télémétrie         | non implémenté                            |
| Séparation GPS et IoT          | prévue                                    |
| Métriques du consommateur      | prévues                                   |
| Traitement Airflow             | expérimental et futur                     |
| Authentification MQTT          | non activée                               |
| TLS MQTT                       | non activé                                |

## Pages associées

- [Contrats de messages](message-contracts.md)
- [Ajouter un service](add-a-service.md)
- [Airflow](airflow.md)
- [Broker MQTT](../services/broker-mqtt.md)
- [Simulateur de drones](../services/drone-simulator.md)
- [Flux de données](../architecture/data-flow.md)
