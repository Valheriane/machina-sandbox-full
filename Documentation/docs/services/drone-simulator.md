# Simulateur de drones

Le simulateur de drones permet de produire des véhicules virtuels capables de recevoir des commandes MQTT, de modifier leur état et de publier de la télémétrie.

Il sert principalement à tester :

- Fleet API ;
- le broker MQTT ;
- le frontend ;
- les contrats de messages ;
- de futurs services consommateurs de données IoT ou GPS.

!!! info "Simulation générique"

    Le modèle actuel représente un drone générique.

    Il ne distingue pas encore les véhicules :

    - aériens ;
    - terrestres ;
    - marins.

    Les mêmes états, commandes et règles de déplacement sont utilisés pour tous les véhicules simulés.

## Deux implémentations présentes

Le dépôt contient actuellement deux implémentations proches du simulateur.

| Implémentation     | Emplacement                    | Utilisation                              |
| ------------------ | ------------------------------ | ---------------------------------------- |
| Agent autonome     | `Application/agents/drone/`    | processus Python indépendant             |
| Simulateur intégré | `Application/fleet-api/sim.py` | worker démarré et contrôlé par Fleet API |

Les deux implémentations utilisent les mêmes familles de topics MQTT et un modèle de déplacement similaire.

!!! warning "Implémentations non totalement équivalentes"

    Les deux simulateurs présentent déjà quelques différences de comportement.

    Par exemple, la commande `rth` est implémentée dans l’agent autonome, mais reste incomplète dans le simulateur intégré à Fleet API.

## Agent autonome

L’agent autonome se trouve dans :

```text
Application/agents/drone/
```

Le dossier contient notamment :

```text
config.py
drone_agent.py
sim_models.py
security.py
Dockerfile
requirements.txt
```

## Technologies

L’agent utilise :

| Technologie    | Rôle                                   |
| -------------- | -------------------------------------- |
| Python 3.11    | exécution du simulateur                |
| Paho MQTT      | connexion au broker                    |
| Threads Python | publication de télémétrie en parallèle |
| HMAC-SHA256    | vérification des commandes             |
| JSON           | format des messages                    |

L’image Docker est basée sur :

```text
python:3.11-slim
```

La dépendance Python principale est :

```text
paho-mqtt
```

!!! note "Version non verrouillée"

    La version de `paho-mqtt` n’est actuellement pas fixée dans `requirements.txt`.

    Cela facilite les essais, mais peut rendre les installations moins reproductibles lorsqu’une nouvelle version de la bibliothèque est publiée.

## Configuration

La configuration est chargée depuis les variables d’environnement.

### Identification

| Variable       | Valeur par défaut | Rôle                    |
| -------------- | ----------------- | ----------------------- |
| `DRONE_ID`     | `drone-001`       | identifiant du drone    |
| `TOPIC_PREFIX` | `lab`             | préfixe des topics MQTT |

### Connexion MQTT

| Variable        | Valeur par défaut       | Rôle                         |
| --------------- | ----------------------- | ---------------------------- |
| `MQTT_HOST`     | `localhost`             | adresse du broker            |
| `MQTT_PORT`     | `1883`                  | port MQTT TCP                |
| `MQTT_USERNAME` | vide                    | utilisateur MQTT facultatif  |
| `MQTT_PASSWORD` | vide                    | mot de passe MQTT facultatif |
| `SHARED_SECRET` | valeur de développement | secret HMAC partagé          |

L’authentification MQTT n’est utilisée que si `MQTT_USERNAME` contient une valeur.

!!! danger "Secret HMAC"

    La valeur réelle de `SHARED_SECRET` ne doit jamais être enregistrée dans Git ou publiée dans la documentation.

    La valeur par défaut est uniquement destinée au développement local.

### Position de départ

| Variable    | Valeur par défaut | Rôle               |
| ----------- | ----------------: | ------------------ |
| `START_LAT` |         `48.8566` | latitude initiale  |
| `START_LON` |          `2.3522` | longitude initiale |
| `START_ALT` |             `0.0` | altitude initiale  |

Les coordonnées par défaut correspondent à une position de démonstration.

### Dynamique

| Variable               | Valeur par défaut | Rôle                      |
| ---------------------- | ----------------: | ------------------------- |
| `PUBLISH_INTERVAL_SEC` |             `1.0` | intervalle de publication |
| `CRUISE_SPEED_MPS`     |             `8.0` | vitesse de déplacement    |
| `BATTERY_DRAIN`        |           `0.005` | facteur de consommation   |
| `HEADING_NOISE`        |             `0.0` | bruit appliqué au cap     |

## État simulé

L’état courant est représenté par `DroneState`.

| Champ         | Type   | Description                   |
| ------------- | ------ | ----------------------------- |
| `lat`         | nombre | latitude                      |
| `lon`         | nombre | longitude                     |
| `alt`         | nombre | altitude                      |
| `speed_mps`   | nombre | vitesse en mètres par seconde |
| `battery_pct` | nombre | niveau de batterie            |
| `status`      | chaîne | état du drone                 |
| `heading_deg` | nombre | cap en degrés                 |

Les états prévus dans le modèle sont :

```text
idle
flying
landing
error
```

L’état `error` existe dans le modèle, mais aucun comportement détaillé d’erreur n’est actuellement simulé.

## Topics MQTT

La base des topics est construite ainsi :

```text
{TOPIC_PREFIX}/drone/{DRONE_ID}
```

Avec les valeurs par défaut :

```text
lab/drone/drone-001
```

Les topics utilisés sont :

| Topic                            | Direction       | Rôle                      |
| -------------------------------- | --------------- | ------------------------- |
| `lab/drone/{drone_id}/commands`  | vers le drone   | réception des commandes   |
| `lab/drone/{drone_id}/telemetry` | depuis le drone | publication de télémétrie |
| `lab/drone/{drone_id}/events`    | depuis le drone | publication d’événements  |

## Connexion au broker

Lorsque l’agent se connecte au broker, il :

1. s’abonne au topic `commands` ;
2. publie un événement de connexion ;
3. démarre la boucle de télémétrie.

L’événement de connexion suit actuellement cette structure :

```json
{
  "type": "status",
  "message": "connected",
  "ts": 1710000000.0
}
```

Cet événement est publié avec :

```text
QoS 1
```

## Format des commandes

Une commande MQTT doit contenir :

```json
{
  "payload": {
    "cmd": "commande",
    "args": {}
  },
  "sig": "signature-hmac"
}
```

L’agent vérifie que :

- `payload` est un objet JSON ;
- `sig` est une chaîne ;
- la signature HMAC correspond au contenu du payload.

Une commande dont la signature est invalide est rejetée.

## Signature HMAC

La signature utilise :

```text
HMAC-SHA256
```

Le payload est sérialisé en JSON avec :

- des clés triées ;
- des séparateurs compacts ;
- un encodage en octets.

La comparaison utilise :

```text
hmac.compare_digest
```

Cette méthode réduit les risques liés aux comparaisons temporelles classiques.

!!! warning "Signature sans chiffrement"

    HMAC permet de vérifier l’intégrité et l’origine d’une commande lorsque le secret reste confidentiel.

    HMAC ne chiffre pas le contenu du message.

    Les commandes restent lisibles sur le réseau tant que MQTT n’utilise pas TLS.

## Commandes disponibles

### `ping`

Demande au drone de répondre par un événement.

Commande :

```json
{
  "cmd": "ping",
  "args": {}
}
```

Événement produit :

```json
{
  "type": "pong",
  "ts": 1710000000.0
}
```

### `takeoff`

Place le drone dans l’état :

```text
flying
```

et augmente son altitude.

Exemple :

```json
{
  "cmd": "takeoff",
  "args": {
    "alt": 20
  }
}
```

L’altitude par défaut est `10.0` lorsque `alt` n’est pas fourni.

### `land`

Place le drone dans l’état :

```text
landing
```

L’altitude devient immédiatement :

```text
0.0
```

Le waypoint courant est supprimé.

!!! note "Atterrissage simplifié"

    L’atterrissage est instantané.

    Il n’existe actuellement aucune phase de descente progressive, de contrôle du sol ou de validation de la zone d’atterrissage.

### `goto`

Définit une nouvelle destination avec une latitude, une longitude et éventuellement une altitude.

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

Le drone passe dans l’état :

```text
flying
```

puis se déplace vers le waypoint.

### `rth`

`rth` signifie **Return To Home**.

Dans l’agent autonome, la commande définit comme destination les coordonnées initiales configurées avec :

```text
START_LAT
START_LON
```

Le drone passe ensuite dans l’état `flying`.

!!! warning "Différence avec Fleet API"

    Dans `Application/fleet-api/sim.py`, la commande `rth` n’est pas encore réellement implémentée.

    Le code contient actuellement une instruction `pass`.

### Commande inconnue

Une commande non reconnue est seulement signalée dans les logs :

```text
[CMD] Unknown command
```

Aucun événement MQTT d’erreur n’est actuellement renvoyé.

## Modèle de déplacement

La fonction `move_towards` déplace progressivement le drone vers un waypoint.

Le calcul repose sur :

```text
1 degré ≈ 111 kilomètres
```

La distance entre la position et la destination est calculée avec une distance euclidienne sur les différences de latitude et de longitude.

À chaque itération :

1. la distance restante est calculée ;
2. un pas dépendant de la vitesse et du temps est déterminé ;
3. la latitude et la longitude sont mises à jour ;
4. le cap est recalculé ;
5. la batterie diminue.

## Cap

Le cap est calculé à partir de la direction du déplacement puis normalisé entre :

```text
0 et 360 degrés
```

Un bruit aléatoire facultatif peut être appliqué grâce à :

```text
HEADING_NOISE
```

## Batterie

La consommation suit actuellement cette formule simplifiée :

```text
consommation = facteur × vitesse × durée
```

Le niveau de batterie ne peut pas descendre sous :

```text
0 %
```

!!! warning "Aucune réaction à une batterie vide"

    Le simulateur ne déclenche actuellement ni atterrissage automatique, ni erreur, ni retour au point de départ lorsque la batterie atteint zéro.

## Arrivée au waypoint

Le drone est considéré comme arrivé lorsque les différences de latitude et de longitude sont inférieures à :

```text
0.00001 degré
```

Le waypoint est alors supprimé et l’état devient :

```text
idle
```

## Télémétrie

Le payload de télémétrie prévu est :

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

La télémétrie est publiée sur :

```text
lab/drone/{drone_id}/telemetry
```

avec :

```text
QoS 0
```

## Point à vérifier dans l’agent autonome

Dans la version auditée de :

```text
Application/agents/drone/drone_agent.py
```

la construction du payload et sa publication semblent indentées en dehors de :

```python
while _running:
```

Si cette indentation est bien celle du fichier, la télémétrie n’est pas publiée périodiquement pendant l’exécution normale.

Le bloc concerné doit être vérifié avant de considérer l’agent autonome comme opérationnel.

Une inspection utile est :

```bash
nl -ba Application/agents/drone/drone_agent.py | sed -n '85,140p'
```

!!! warning "État actuel"

    Le simulateur intégré à Fleet API contient bien une publication périodique dans sa boucle.

    L’agent autonome nécessite une vérification ou une correction de son indentation.

## Simulateur intégré à Fleet API

Le fichier :

```text
Application/fleet-api/sim.py
```

définit un `DroneWorker`.

Chaque worker possède :

- son identifiant ;
- son préfixe MQTT ;
- sa configuration de connexion ;
- son secret partagé ;
- sa position initiale ;
- sa vitesse ;
- son facteur de consommation ;
- son bruit de cap ;
- son thread d’exécution.

Fleet API peut ainsi gérer plusieurs simulations indépendantes dans son propre processus.

## Paramètres stockés par Fleet API

Le modèle de données contient :

| Champ                  | Valeur par défaut |
| ---------------------- | ----------------: |
| `topic_prefix`         |             `lab` |
| `start_lat`            |         `48.8566` |
| `start_lon`            |          `2.3522` |
| `start_alt`            |             `0.0` |
| `publish_interval_sec` |             `1.0` |
| `cruise_speed_mps`     |             `8.0` |
| `battery_drain`        |           `0.005` |
| `heading_noise`        |             `0.0` |
| `status`               |         `stopped` |

Le statut enregistré par Fleet API distingue actuellement :

```text
stopped
running
```

Ce statut de gestion ne correspond pas exactement au statut physique simulé :

```text
idle
flying
landing
error
```

## Déploiement actuel

L’agent autonome dispose d’un Dockerfile, mais il n’est actuellement déclaré ni dans :

```text
Application/docker-compose.yml
```

ni dans :

```text
Application/machina-sandbox/
```

Les déploiements actuels lancent :

- le broker ;
- Fleet API ;
- le frontend.

La simulation utilisée par l’application repose donc principalement sur les workers intégrés à Fleet API.

## Limites du modèle actuel

Le modèle ne simule pas encore :

- la différence entre aérien, terrestre et marin ;
- l’accélération ou le freinage ;
- une montée ou une descente progressive ;
- le vent ;
- les courants marins ;
- la pente ou la nature du terrain ;
- les obstacles ;
- les collisions ;
- les zones interdites ;
- la portée radio ;
- les pertes GPS ;
- les pannes de moteur ;
- la température ;
- la charge utile ;
- la consommation propre à chaque équipement ;
- la réaction à une batterie vide ;
- la précision variable des capteurs ;
- une dynamique physique réaliste.

La Terre est assimilée à un plan local et la conversion géographique reste approximative.

## Absence de type de véhicule

Le modèle ne contient actuellement aucun champ tel que :

```text
vehicle_type
drone_type
domain
```

Il n’existe donc aucune validation permettant d’empêcher :

- un véhicule terrestre de recevoir une altitude ;
- un véhicule marin de se déplacer sur la terre ;
- un drone aérien de traverser un obstacle ;
- un véhicule de circuler dans une zone incompatible.

Tous les drones utilisent les mêmes commandes et le même modèle cinématique.

## Évolution vers plusieurs domaines

Une évolution possible consiste à introduire un domaine :

```text
air
ground
marine
```

Le modèle pourrait ensuite définir des comportements spécialisés.

### Drone aérien

Paramètres possibles :

- altitude minimale et maximale ;
- vitesse verticale ;
- vent ;
- consommation liée à la montée ;
- retour automatique ;
- zone d’atterrissage ;
- perte de portance.

### Drone terrestre

Paramètres possibles :

- routes praticables ;
- pente ;
- adhérence ;
- vitesse selon le terrain ;
- obstacles ;
- rayon de braquage ;
- franchissement.

### Drone marin

Paramètres possibles :

- surface ou profondeur ;
- courant ;
- dérive ;
- état de la mer ;
- autonomie ;
- remontée d’urgence ;
- zones navigables.

!!! info "Évolution future"

    Cette différenciation n’est pas encore implémentée.

    La première étape pourrait consister à ajouter un champ de type au modèle sans modifier immédiatement toute la simulation.

## Évolution vers une simulation plus réaliste

Une progression raisonnable pourrait être :

1. corriger et stabiliser la boucle de l’agent autonome ;
2. harmoniser l’agent autonome et `DroneWorker` ;
3. implémenter réellement `rth` dans les deux simulateurs ;
4. ajouter les événements de rejet et d’erreur ;
5. introduire un type de véhicule ;
6. séparer les modèles aérien, terrestre et marin ;
7. ajouter des contraintes géographiques ;
8. enrichir la consommation de batterie ;
9. simuler les capteurs et leurs erreurs ;
10. intégrer plusieurs services consommateurs de télémétrie.

## Séparation future des données

La télémétrie est actuellement publiée dans un seul message.

Elle pourrait être séparée en plusieurs flux :

```text
lab/drone/{drone_id}/telemetry/iot
lab/drone/{drone_id}/telemetry/gps
lab/drone/{drone_id}/telemetry/energy
lab/drone/{drone_id}/telemetry/navigation
```

Cette organisation permettrait à chaque service de ne consommer que les données utiles.

Par exemple :

```text
lab/drone/+/telemetry/gps
```

pour un service cartographique, et :

```text
lab/drone/+/telemetry/iot
```

pour un service de traitement des capteurs.

## Pages associées

- [Broker MQTT](broker-mqtt.md)
- [Fleet API](fleet-api.md)
- [Frontend](frontend.md)
- [Flux de données](../architecture/data-flow.md)
- [Contrats de messages](../integrations/message-contracts.md)
