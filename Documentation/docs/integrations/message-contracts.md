# Contrats de messages

Cette page décrit les topics MQTT et les formats de messages actuellement utilisés par **Machina Sandbox Full**.

Ces contrats sont encore expérimentaux. Ils doivent être stabilisés avant d’être utilisés par plusieurs services indépendants ou considérés comme une interface publique durable.

## Vue générale

Les échanges MQTT sont organisés autour de trois familles de messages :

| Famille    | Direction principale         | Rôle                                  |
| ---------- | ---------------------------- | ------------------------------------- |
| Commandes  | Fleet API vers le drone      | demander une action                   |
| Télémétrie | drone vers les consommateurs | publier l’état courant                |
| Événements | drone vers les consommateurs | signaler une connexion ou une réponse |

Le préfixe utilisé par défaut est :

```text
lab
```

## Structure des topics

La structure générale est :

```text
{topic_prefix}/drone/{drone_id}/{message_type}
```

Avec les valeurs par défaut :

```text
lab/drone/drone-001/commands
lab/drone/drone-001/telemetry
lab/drone/drone-001/events
```

| Élément        | Exemple     | Description                 |
| -------------- | ----------- | --------------------------- |
| `topic_prefix` | `lab`       | espace logique du projet    |
| `drone`        | `drone`     | catégorie de ressource      |
| `drone_id`     | `drone-001` | identifiant unique du drone |
| `message_type` | `telemetry` | nature du message           |

## Préfixe configurable

Chaque drone enregistré dans Fleet API possède un champ :

```text
topic_prefix
```

Sa valeur par défaut est :

```text
lab
```

Une flotte pourrait donc utiliser un autre préfixe :

```text
test/drone/drone-001/telemetry
production/drone/drone-001/telemetry
```

!!! warning "Frontend actuellement limité à `lab`"

    Le frontend s’abonne actuellement à des topics commençant explicitement par :

    ```text
    lab/drone/
    ```

    Un drone utilisant un autre `topic_prefix` peut être géré par Fleet API, mais sa télémétrie ne sera pas automatiquement reçue par les composants frontend actuels.

    Le préfixe devrait être rendu configurable ou transmis dynamiquement au frontend.

## Topic de commandes

Le topic de commandes suit la structure :

```text
{topic_prefix}/drone/{drone_id}/commands
```

Exemple :

```text
lab/drone/drone-001/commands
```

### Producteur

Fleet API publie les commandes.

### Consommateurs

Les implémentations suivantes s’abonnent à ce topic :

- le `DroneWorker` intégré à Fleet API ;
- l’agent autonome situé dans `Application/agents/drone/`.

### Niveau de qualité

Fleet API publie actuellement les commandes avec :

```text
QoS 0
```

!!! warning "Livraison non garantie"

    Avec QoS 0, une commande peut être perdue en cas de rupture réseau ou de déconnexion temporaire.

    Pour des commandes critiques, une évolution vers QoS 1 pourrait être étudiée avec une gestion de l’idempotence et des accusés de réception applicatifs.

## Enveloppe d’une commande

Une commande MQTT est placée dans une enveloppe contenant :

```json
{
  "sig": "signature-hmac",
  "payload": {
    "cmd": "ping"
  }
}
```

L’enveloppe comporte deux champs obligatoires :

| Champ     | Type   | Description               |
| --------- | ------ | ------------------------- |
| `sig`     | chaîne | signature HMAC du payload |
| `payload` | objet  | commande et arguments     |

L’agent rejette un message lorsque :

- le JSON est invalide ;
- `payload` n’est pas un objet ;
- `sig` n’est pas une chaîne ;
- la signature ne correspond pas au payload.

## Payload de commande

La structure générale est :

```json
{
  "cmd": "nom-de-la-commande",
  "args": {}
}
```

Le champ `args` est facultatif.

Lorsqu’aucun argument n’est fourni, Fleet API peut produire :

```json
{
  "cmd": "ping"
}
```

## Commandes actuellement reconnues

| Commande  | Arguments principaux           | Effet                                           |
| --------- | ------------------------------ | ----------------------------------------------- |
| `ping`    | aucun                          | publie un événement `pong`                      |
| `takeoff` | `alt` facultatif               | passe à l’état `flying` et augmente l’altitude  |
| `land`    | aucun                          | met l’altitude à zéro et annule le waypoint     |
| `goto`    | `lat`, `lon`, `alt` facultatif | définit une destination                         |
| `rth`     | aucun                          | retour au point de départ dans l’agent autonome |

## Commande `ping`

Exemple de payload :

```json
{
  "cmd": "ping"
}
```

Le drone publie ensuite un événement :

```json
{
  "type": "pong",
  "ts": 1710000000.0
}
```

## Commande `takeoff`

Exemple :

```json
{
  "cmd": "takeoff",
  "args": {
    "alt": 20
  }
}
```

Lorsque `alt` est absent, l’altitude demandée par défaut est :

```text
10.0
```

Le simulateur place le drone dans l’état :

```text
flying
```

!!! note "Décollage simplifié"

    Le changement d’altitude est immédiat.

    Le modèle ne simule actuellement ni vitesse verticale, ni durée de décollage, ni validation du type de véhicule.

## Commande `land`

Exemple :

```json
{
  "cmd": "land"
}
```

Effets actuels :

- état `landing` ;
- altitude mise immédiatement à `0.0` ;
- waypoint supprimé.

Le simulateur ne réalise pas de descente progressive.

## Commande `goto`

Exemple :

```json
{
  "cmd": "goto",
  "args": {
    "lat": 48.857,
    "lon": 2.36,
    "alt": 30
  }
}
```

Champs :

| Champ | Obligatoire | Description              |
| ----- | ----------- | ------------------------ |
| `lat` | oui         | latitude de destination  |
| `lon` | oui         | longitude de destination |
| `alt` | non         | altitude demandée        |

Le drone passe dans l’état :

```text
flying
```

puis se déplace progressivement vers le waypoint.

## Commande `rth`

`rth` signifie **Return To Home**.

Exemple :

```json
{
  "cmd": "rth"
}
```

Dans l’agent autonome, le point de départ est défini par :

```text
START_LAT
START_LON
```

!!! warning "Implémentation différente"

    Dans `Application/fleet-api/sim.py`, la branche correspondant à `rth` contient actuellement seulement :

    ```python
    pass
    ```

    Le retour au point de départ n’est donc pas opérationnel dans le simulateur intégré à Fleet API.

## Signature HMAC

Fleet API signe le contenu de `payload` avec :

```text
HMAC-SHA256
```

Le JSON est sérialisé avec :

- les clés triées ;
- des séparateurs compacts ;
- un encodage en octets.

La logique utilisée est équivalente à :

```python
body = json.dumps(
    payload,
    separators=(",", ":"),
    sort_keys=True,
).encode()
```

La signature est ensuite calculée avec le secret partagé.

## Comparaison sécurisée

Le simulateur vérifie la signature avec :

```text
hmac.compare_digest
```

Cette fonction réalise une comparaison adaptée aux données cryptographiques.

!!! danger "Secret partagé"

    Le secret HMAC ne doit jamais être publié dans la documentation, dans Git ou dans les logs.

    Fleet API et le simulateur doivent utiliser exactement la même valeur.

## Limites de la signature

HMAC garantit principalement :

- l’intégrité du payload ;
- la connaissance du secret par l’émetteur.

HMAC ne fournit pas :

- le chiffrement du message ;
- la protection contre la réutilisation d’une ancienne commande ;
- l’identification individuelle de plusieurs émetteurs ;
- une gestion des autorisations par commande ;
- une protection réseau lorsque MQTT est utilisé sans TLS.

Le payload reste lisible par un acteur capable d’observer le trafic MQTT.

## Amélioration possible de l’enveloppe

Une future enveloppe pourrait inclure :

```json
{
  "version": "1",
  "message_id": "uuid",
  "issued_at": "2026-08-04T12:00:00Z",
  "expires_at": "2026-08-04T12:00:30Z",
  "source": "fleet-api",
  "payload": {
    "cmd": "goto",
    "args": {}
  },
  "sig": "signature-hmac"
}
```

Ces champs permettraient notamment :

- de versionner le contrat ;
- de détecter les doublons ;
- de rejeter une commande trop ancienne ;
- de tracer la source ;
- de faciliter les audits.

Cette structure n’est pas encore implémentée.

## Topic de télémétrie

La télémétrie est publiée sur :

```text
{topic_prefix}/drone/{drone_id}/telemetry
```

Exemple :

```text
lab/drone/drone-001/telemetry
```

### Producteur

Le simulateur de drone publie la télémétrie.

### Consommateurs actuels

Le frontend s’abonne notamment depuis :

- `TelemetryFeed` ;
- `MapPanel`.

### Niveau de qualité

La publication utilise actuellement :

```text
QoS 0
```

La fréquence par défaut est :

```text
1 message par seconde
```

Cette fréquence est configurable avec :

```text
PUBLISH_INTERVAL_SEC
```

ou avec le champ Fleet API :

```text
publish_interval_sec
```

## Payload de télémétrie

Le payload actuellement produit est :

```json
{
  "drone_id": "drone-001",
  "ts": 1710000000.0,
  "position": {
    "lat": 48.8566,
    "lon": 2.3522,
    "alt": 10.0
  },
  "speed_mps": 8.0,
  "battery_pct": 99.8,
  "status": "flying",
  "heading_deg": 90.0
}
```

## Champs de télémétrie

| Champ          | Type   | Unité                        | Description               |
| -------------- | ------ | ---------------------------- | ------------------------- |
| `drone_id`     | chaîne | —                            | identifiant du drone      |
| `ts`           | nombre | secondes Unix                | horodatage de publication |
| `position.lat` | nombre | degrés                       | latitude                  |
| `position.lon` | nombre | degrés                       | longitude                 |
| `position.alt` | nombre | non explicitement stabilisée | altitude                  |
| `speed_mps`    | nombre | m/s                          | vitesse                   |
| `battery_pct`  | nombre | pourcentage                  | niveau de batterie        |
| `status`       | chaîne | —                            | état physique simulé      |
| `heading_deg`  | nombre | degrés                       | cap entre 0 et 360        |

!!! warning "Unité de l’altitude"

    Le code manipule l’altitude comme un nombre, mais le contrat ne déclare pas explicitement son unité.

    Par cohérence avec les autres paramètres, elle semble représenter des mètres, mais ce point doit être officialisé dans une future version du contrat.

## États physiques

Les états prévus dans le simulateur sont :

```text
idle
flying
landing
error
```

Le statut `error` est défini dans le modèle, mais aucun scénario détaillé ne le produit actuellement.

## Statut Fleet API et statut physique

Fleet API expose aussi un statut de gestion :

```text
running
stopped
```

Ces valeurs indiquent si le thread du worker fonctionne.

Elles ne doivent pas être confondues avec les états physiques de télémétrie :

```text
idle
flying
landing
error
```

## Abonnement wildcard à la télémétrie

Le frontend utilise :

```text
lab/drone/+/telemetry
```

Le caractère `+` représente un seul niveau variable.

Cet abonnement reçoit donc :

```text
lab/drone/drone-001/telemetry
lab/drone/drone-002/telemetry
lab/drone/vehicle-alpha/telemetry
```

Il ne reçoit pas les sous-topics plus profonds, par exemple :

```text
lab/drone/drone-001/telemetry/gps
```

Pour recevoir tous les futurs sous-types de télémétrie, un abonnement possible serait :

```text
lab/drone/+/telemetry/#
```

Cette structure n’est pas encore utilisée.

## Topic d’événements

Les événements sont publiés sur :

```text
{topic_prefix}/drone/{drone_id}/events
```

Exemple :

```text
lab/drone/drone-001/events
```

## Événement de connexion

Lors de la connexion MQTT du drone :

```json
{
  "type": "status",
  "message": "connected",
  "ts": 1710000000.0
}
```

La publication utilise actuellement :

```text
QoS 1
```

## Événement `pong`

En réponse à `ping` :

```json
{
  "type": "pong",
  "ts": 1710000000.0
}
```

Aucun identifiant de commande ou de corrélation n’est actuellement présent.

## Erreurs et rejets

Les erreurs suivantes sont actuellement écrites dans les logs du simulateur :

```text
Invalid JSON
Missing payload/sig
Signature invalid
Unknown command
```

Aucun événement MQTT structuré n’est publié en réponse à ces erreurs.

!!! warning "Absence d’accusé de réception"

    À l’exception de `ping`, Fleet API ne reçoit aucun message confirmant qu’une commande a été appliquée.

    Une publication MQTT réussie confirme seulement que le client a transmis le message au mécanisme MQTT local, pas que le drone l’a exécuté.

## Abonnement frontend aux commandes

`MapPanel.jsx` contient actuellement un abonnement à :

```text
lab/drone/+/commands
```

Cet abonnement permet au navigateur d’observer les commandes publiées pour les drones.

!!! warning "Visibilité des commandes"

    Les enveloppes de commandes peuvent contenir la signature et les arguments transmis au drone.

    Cet abonnement est utile pour l’expérimentation, mais devra être réévalué si les commandes contiennent des données sensibles ou si des contrôles d’accès MQTT sont introduits.

## Incohérence d’affichage dans `DroneTable`

Le tableau du frontend affiche actuellement un topic sous la forme :

```text
lab/{drone_id}/telemetry
```

Le contrat réellement utilisé par Fleet API et les simulateurs est :

```text
lab/drone/{drone_id}/telemetry
```

!!! warning "Affichage à corriger"

    Le segment `/drone/` manque dans le texte affiché par `DroneTable.jsx`.

    Cette anomalie concerne l’affichage du frontend, pas la construction réelle des topics MQTT par Fleet API.

## Incohérence des préfixes dans le frontend

Le formulaire permet de définir :

```text
topic_prefix
```

Cependant, les abonnements frontend utilisent directement :

```text
lab/drone/+/telemetry
lab/drone/+/commands
```

Un drone défini avec :

```text
topic_prefix=test
```

publierait sur :

```text
test/drone/{drone_id}/telemetry
```

mais ne serait pas observé par les abonnements actuels du frontend.

## Contrat générique et types de véhicules

La télémétrie actuelle ne contient aucun champ indiquant le type de véhicule.

Il n’existe pas encore de champ comme :

```text
vehicle_type
domain
platform_type
```

Le même contrat est donc utilisé pour :

- un drone aérien ;
- un véhicule terrestre ;
- un véhicule marin.

!!! info "Évolution envisagée"

    Un futur champ pourrait distinguer :

    ```text
    air
    ground
    marine
    ```

    Les champs obligatoires et les commandes autorisées pourraient ensuite varier selon le domaine.

## Exemple d’enveloppe enrichie de télémétrie

Une future version pourrait utiliser :

```json
{
  "schema_version": "1.0",
  "message_id": "uuid",
  "source": {
    "vehicle_id": "drone-001",
    "domain": "air"
  },
  "timestamp": "2026-08-04T12:00:00Z",
  "telemetry": {
    "position": {
      "lat": 48.8566,
      "lon": 2.3522,
      "alt_m": 30
    },
    "velocity": {
      "speed_mps": 8,
      "heading_deg": 90
    },
    "energy": {
      "battery_pct": 99
    },
    "status": "flying"
  }
}
```

Cette enveloppe n’est pas encore implémentée.

## Séparation future de la télémétrie

Une évolution envisagée consiste à séparer les données selon leur domaine fonctionnel.

### Données GPS

```text
lab/drone/{drone_id}/telemetry/gps
```

Exemple :

```json
{
  "ts": 1710000000.0,
  "lat": 48.8566,
  "lon": 2.3522,
  "alt_m": 30,
  "heading_deg": 90,
  "speed_mps": 8
}
```

### Données IoT

```text
lab/drone/{drone_id}/telemetry/iot
```

Exemple futur :

```json
{
  "ts": 1710000000.0,
  "temperature_c": 22.4,
  "humidity_pct": 54,
  "pressure_hpa": 1013
}
```

### Énergie

```text
lab/drone/{drone_id}/telemetry/energy
```

Exemple futur :

```json
{
  "ts": 1710000000.0,
  "battery_pct": 82,
  "voltage_v": 14.8,
  "current_a": 2.1
}
```

!!! note "Formats uniquement illustratifs"

    Les topics spécialisés et leurs payloads ne sont pas encore implémentés.

    Les exemples montrent une direction possible, mais ne constituent pas encore des contrats officiels.

## Abonnements futurs

Un consommateur GPS pourrait utiliser :

```text
lab/drone/+/telemetry/gps
```

Un consommateur IoT :

```text
lab/drone/+/telemetry/iot
```

Un service d’archivage général :

```text
lab/drone/+/telemetry/#
```

Un service consommant tous les événements :

```text
lab/drone/+/events
```

## Versionnement

Les messages actuels ne contiennent aucun numéro de version.

Une évolution incompatible du payload pourrait donc casser silencieusement les consommateurs existants.

Plusieurs stratégies sont possibles.

### Version dans le payload

```json
{
  "schema_version": "1.0",
  "data": {}
}
```

### Version dans le topic

```text
lab/v1/drone/{drone_id}/telemetry
```

### Registry de schémas

Les schémas JSON pourraient être stockés dans le dépôt et validés automatiquement.

Aucune stratégie n’est actuellement mise en œuvre.

## Règles recommandées pour les évolutions

Lors de l’évolution des contrats :

1. ne pas modifier silencieusement le sens d’un champ existant ;
2. préciser les unités ;
3. ajouter un numéro de version ;
4. documenter les champs obligatoires et facultatifs ;
5. fournir des exemples valides ;
6. ajouter des tests de sérialisation ;
7. prévoir la compatibilité avec les consommateurs existants ;
8. distinguer les messages temps réel des traitements différés ;
9. éviter de publier des secrets ;
10. documenter le QoS et la politique de rétention.

## État actuel des contrats

| Élément                                  | État               |
| ---------------------------------------- | ------------------ |
| Topics `commands`, `telemetry`, `events` | opérationnels      |
| Préfixe personnalisable dans Fleet API   | opérationnel       |
| Préfixe dynamique dans le frontend       | non pris en charge |
| Signature HMAC des commandes             | opérationnelle     |
| Chiffrement MQTT                         | non implémenté     |
| Accusés de réception généraux            | non implémentés    |
| Versionnement des messages               | non implémenté     |
| Séparation GPS et IoT                    | prévue             |
| Types aérien, terrestre et marin         | prévus             |
| Schémas JSON validés automatiquement     | non implémentés    |

## Fichiers de référence

Les contrats actuels sont principalement définis dans :

```text
Application/fleet-api/manager.py
Application/fleet-api/sim.py
Application/fleet-api/models.py
Application/fleet-api/security.py
Application/agents/drone/drone_agent.py
Application/agents/drone/security.py
Application/front/src/components/TelemetryFeed.jsx
Application/front/src/components/MapPanel.jsx
```

## Pages associées

- [Flux de données](../architecture/data-flow.md)
- [Broker MQTT](../services/broker-mqtt.md)
- [Simulateur de drones](../services/drone-simulator.md)
- [Consommer la télémétrie](telemetry-consumer.md)
- [Airflow](airflow.md)
