# Broker MQTT

Le broker MQTT assure le transport des messages entre Fleet API, les simulateurs de drones, le frontend et les futurs services consommateurs.

Le projet utilise l’image Docker officielle :

```text
eclipse-mosquitto:2
```

Le broker reste volontairement simple afin de servir de support d’apprentissage et d’expérimentation.

## Rôle

Le broker transporte principalement trois familles de messages :

| Famille    | Direction principale          | Rôle                                    |
| ---------- | ----------------------------- | --------------------------------------- |
| Commandes  | Fleet API vers les drones     | ordres envoyés à un drone               |
| Télémétrie | Drones vers les consommateurs | mesures et état courant                 |
| Événements | Drones vers les consommateurs | connexion, réponse ou changement d’état |

Les topics actuels suivent cette structure :

```text
lab/drone/{drone_id}/commands
lab/drone/{drone_id}/telemetry
lab/drone/{drone_id}/events
```

Le broker ne produit pas lui-même les messages. Il reçoit les publications et les distribue aux clients abonnés aux topics correspondants.

## Emplacement

Les fichiers utilisés pour le mode Docker Compose sont présents dans :

```text
Application/broker/
```

Le dossier contient actuellement :

```text
mosquitto.conf
mosquitto.db
passwords.txt
```

| Fichier          | Rôle                                              |
| ---------------- | ------------------------------------------------- |
| `mosquitto.conf` | configuration de Mosquitto en mode Docker Compose |
| `mosquitto.db`   | base de persistance générée par Mosquitto         |
| `passwords.txt`  | fichier prévu pour une future authentification    |

!!! danger "Fichiers sensibles ou générés"

    Le contenu de `passwords.txt` ne doit jamais être publié dans la documentation, les logs ou les captures d’écran.

    `mosquitto.db` est un fichier de données généré par Mosquitto. Il ne doit pas être modifié manuellement.

## Configuration Docker Compose

La configuration locale se trouve dans :

```text
Application/broker/mosquitto.conf
```

Elle définit actuellement deux listeners.

### MQTT TCP

```text
listener 1883
allow_anonymous true
```

Ce listener est utilisé par :

- Fleet API ;
- les simulateurs de drones ;
- les futurs services consommateurs MQTT ;
- les outils MQTT en ligne de commande.

### MQTT WebSocket

```text
listener 9001
protocol websockets
allow_anonymous true
```

Ce listener permet notamment au frontend exécuté dans un navigateur de se connecter au broker.

Un navigateur ne se connecte pas directement au protocole MQTT TCP classique. Il utilise MQTT transporté sur WebSocket.

## Ports Docker Compose

| Protocole      | Port du conteneur | Port hôte par défaut |
| -------------- | ----------------: | -------------------: |
| MQTT TCP       |            `1883` |               `1883` |
| MQTT WebSocket |            `9001` |               `9001` |

Les ports exposés sur l’hôte peuvent être modifiés dans :

```text
Application/.env
```

Les variables correspondantes sont :

```text
MACHINA_MQTT_PORT
MACHINA_MQTT_WS_PORT
```

Pour vérifier les valeurs réellement utilisées :

```bash
make compose-config
```

## Réseau Docker Compose

Le service Compose porte le nom :

```text
broker
```

Les autres conteneurs du réseau Docker peuvent donc le joindre avec :

```text
broker:1883
```

Le nom du réseau Docker Compose est :

```text
iotnet
```

Fleet API reçoit notamment :

```text
MQTT_HOST=broker
MQTT_PORT=1883
```

Depuis la machine hôte, les adresses sont plutôt :

```text
MQTT TCP : localhost:1883
MQTT WS  : ws://localhost:9001
```

## Persistance Docker Compose

La configuration active la persistance :

```text
persistence true
persistence_location /mosquitto/data/
```

Docker Compose monte le dossier :

```text
Application/broker/
```

dans le conteneur à l’emplacement :

```text
/mosquitto/data
```

Mosquitto peut ainsi créer et conserver :

```text
Application/broker/mosquitto.db
```

Le fichier peut rester présent après l’arrêt du conteneur.

!!! warning "Ne pas supprimer sans vérification"

    `make compose-down` arrête les conteneurs, mais ne supprime pas automatiquement les fichiers présents dans le dossier lié.

    Ne supprime pas `mosquitto.db` sans avoir vérifié que les données persistées ne sont plus nécessaires.

## Logs

La configuration Docker Compose active les niveaux suivants :

```text
log_type error
log_type warning
log_type notice
```

Les messages sont visibles dans les logs du conteneur.

Pour suivre tous les services :

```bash
make compose-logs
```

Pour suivre uniquement le broker :

```bash
docker compose \
  --project-directory Application \
  -f Application/docker-compose.yml \
  logs --follow --tail=100 broker
```

Pour quitter le suivi sans arrêter le broker :

```text
Ctrl+C
```

## Démarrage avec Docker Compose

Depuis la racine du dépôt :

```bash
make compose-config
make compose-up
```

Vérifier ensuite son état :

```bash
make compose-status
```

Le service Compose attendu est :

```text
broker
```

Pour arrêter l’environnement :

```bash
make compose-down
```

## Déploiement Kubernetes

Le broker est également décrit dans le chart Helm :

```text
Application/machina-sandbox/
```

Les fichiers principaux sont :

```text
templates/broker-configmap.yaml
templates/broker-deployment.yaml
templates/broker-service.yaml
```

Le chart crée :

- un ConfigMap contenant la configuration Mosquitto ;
- un Deployment nommé `broker` ;
- un Service nommé `broker`.

## Configuration Helm

La configuration Helm définit actuellement :

```text
listener 1883
protocol mqtt

listener 9001
protocol websockets

listener 9883
protocol http_api
```

Les connexions anonymes sont autorisées avec :

```text
allow_anonymous true
```

!!! warning "Différence entre Compose et Helm"

    La configuration Docker Compose active explicitement la persistance et plusieurs niveaux de logs.

    La configuration Helm actuelle ne contient pas les mêmes directives de persistance.

    Les deux environnements ne sont donc pas encore strictement équivalents.

## Ports Kubernetes

### Ports internes du pod

| Nom         |   Port | Protocole              |
| ----------- | -----: | ---------------------- |
| `mqtt`      | `1883` | MQTT TCP               |
| `websocket` | `9001` | MQTT WebSocket         |
| `http-api`  | `9883` | HTTP interne Mosquitto |

### Service Kubernetes

Le Service publie actuellement uniquement :

| Nom       | Port interne | NodePort |
| --------- | -----------: | -------: |
| MQTT      |       `1883` |  `31883` |
| WebSocket |       `9001` |  `30901` |

Le port `9883` est déclaré dans le conteneur, mais il n’est pas publié par le Service Kubernetes.

Il n’est donc pas accessible avec un NodePort dans la configuration actuelle.

## Accès dans Kubernetes

Depuis un autre pod du même namespace :

```text
broker:1883
broker:9001
```

Depuis l’hôte ou le Dev Container connecté au réseau Minikube :

```text
MQTT TCP : <IP_MINIKUBE>:31883
MQTT WS  : ws://<IP_MINIKUBE>:30901
```

L’adresse de Minikube étant dynamique, utiliser :

```bash
make devcont-status
```

## Contrôle de disponibilité

Le Deployment Kubernetes définit une sonde de disponibilité TCP :

```text
port: mqtt
```

Kubernetes tente donc d’ouvrir une connexion sur le port `1883`.

La sonde utilise actuellement :

| Paramètre               |     Valeur |
| ----------------------- | ---------: |
| Délai initial           |  1 seconde |
| Période                 | 2 secondes |
| Délai d’attente         |  1 seconde |
| Nombre maximal d’échecs |         30 |

Cette vérification confirme que le port MQTT accepte les connexions TCP.

Elle ne vérifie pas la publication ou la réception complète d’un message MQTT.

## Vérifications Kubernetes

### État du déploiement

```bash
kubectl get deployment broker \
  --namespace machina-sandbox
```

### État du pod

```bash
kubectl get pods \
  --namespace machina-sandbox \
  --selector app=broker
```

### État du Service

```bash
kubectl get service broker \
  --namespace machina-sandbox
```

### Logs

```bash
kubectl logs \
  --namespace machina-sandbox \
  deployment/broker \
  --follow
```

### Vérification globale

```bash
make devcont-check
```

Cette cible vérifie notamment que le port MQTT WebSocket est accessible.

## Accès anonyme

Les configurations Docker Compose et Helm autorisent actuellement les connexions anonymes :

```text
allow_anonymous true
```

Cela signifie qu’un client pouvant atteindre le broker peut se connecter sans nom d’utilisateur ni mot de passe.

!!! warning "Configuration réservée au bac à sable"

    Cette configuration facilite les expérimentations locales.

    Elle ne doit pas être utilisée telle quelle pour un broker exposé sur Internet, un réseau non maîtrisé ou un environnement de production.

## Authentification prévue

Le dossier contient déjà :

```text
Application/broker/passwords.txt
```

Toutefois, ce fichier n’est pas utilisé par la configuration actuelle.

Une future configuration authentifiée pourrait utiliser :

```text
allow_anonymous false
password_file /mosquitto/data/passwords.txt
```

La création ou la modification d’utilisateurs devra être réalisée avec l’outil `mosquitto_passwd`.

!!! warning "Fonctionnalité non activée"

    L’authentification n’est pas opérationnelle tant que la configuration conserve `allow_anonymous true`.

    Le simple fait que `passwords.txt` existe ne signifie pas que Mosquitto l’utilise.

!!! note "Nom du conteneur"

    Les anciens commentaires du fichier de configuration mentionnent un conteneur nommé `mqtt-broker`.

    Le fichier Docker Compose actuel utilise un autre nom de conteneur.

    Pour éviter de dépendre d’un nom de conteneur fixé manuellement, les futures commandes devront privilégier :

    ```bash
    docker compose \
      --project-directory Application \
      -f Application/docker-compose.yml \
      exec broker <commande>
    ```

## Séparation future des flux de télémétrie

Le projet utilise actuellement un seul topic de télémétrie par drone :

```text
lab/drone/{drone_id}/telemetry
```

Une évolution prévue consiste à séparer les données selon leur domaine.

Par exemple :

```text
lab/drone/{drone_id}/telemetry/iot
lab/drone/{drone_id}/telemetry/gps
```

Un service spécialisé dans les données IoT pourrait alors s’abonner à :

```text
lab/drone/+/telemetry/iot
```

Un service spécialisé dans les positions GPS pourrait s’abonner à :

```text
lab/drone/+/telemetry/gps
```

Le caractère `+` représente un niveau variable dans un abonnement MQTT. Il permet ici de recevoir les messages de tous les drones sans connaître chaque identifiant à l’avance.

!!! info "Évolution future"

    Cette séparation n’est pas encore implémentée.

    Les topics actuellement confirmés restent :

    ```text
    lab/drone/{drone_id}/commands
    lab/drone/{drone_id}/telemetry
    lab/drone/{drone_id}/events
    ```

## Futurs services consommateurs

La séparation des topics permettra d’expérimenter plusieurs consommateurs indépendants :

| Consommateur envisagé  | Abonnement possible         | Traitement                      |
| ---------------------- | --------------------------- | ------------------------------- |
| Service IoT            | `lab/drone/+/telemetry/iot` | mesures de capteurs             |
| Service GPS            | `lab/drone/+/telemetry/gps` | positions et trajectoires       |
| Archivage              | `lab/drone/+/telemetry/#`   | stockage de toute la télémétrie |
| Détection d’événements | `lab/drone/+/events`        | alertes et changements d’état   |

Le caractère `#` permettrait de recevoir tous les sous-topics situés après `telemetry`.

Ces conventions devront être stabilisées avant leur intégration dans les contrats de messages.

## Place possible d’Airflow

Airflow pourra être expérimenté plus tard pour :

- lancer des traitements périodiques ;
- agréger des données stockées ;
- produire des rapports ;
- orchestrer plusieurs étapes de transformation ;
- rejouer ou contrôler des pipelines planifiés.

Airflow ne remplacerait pas nécessairement les consommateurs MQTT en temps réel.

Une architecture possible serait :

```text
Drones
    |
    v
Broker MQTT
    |
    +--> Consommateur IoT --> stockage IoT
    |
    +--> Consommateur GPS --> stockage GPS
                                  |
                                  v
                              Airflow
                                  |
                                  +--> agrégation
                                  +--> analyse
                                  +--> export
```

Dans cette approche :

- les services consommateurs reçoivent les messages MQTT en continu ;
- Airflow orchestre ensuite des traitements planifiés sur les données enregistrées.

!!! info "Expérimentation future"

    Airflow n’est pas encore présent ni déployé dans le projet.

    Son rôle exact devra être testé avant de choisir entre traitement continu, traitement planifié ou combinaison des deux.

## Limites actuelles

Le broker présente actuellement les limites suivantes :

- accès anonyme ;
- absence de chiffrement TLS ;
- absence de contrôle d’accès par topic ;
- authentification non activée ;
- différences entre les configurations Compose et Helm ;
- persistance Kubernetes non configurée ;
- port HTTP `9883` non exposé ;
- absence de métriques Mosquitto intégrées au monitoring ;
- séparation IoT/GPS encore à concevoir.

## Évolutions possibles

Les évolutions pourront être ajoutées progressivement :

1. stabiliser la structure des topics ;
2. séparer les télémétries IoT et GPS ;
3. ajouter des consommateurs spécialisés ;
4. activer une authentification locale ;
5. définir des droits par utilisateur et par topic ;
6. ajouter TLS ;
7. ajouter une persistance Kubernetes ;
8. exposer des métriques ;
9. expérimenter le traitement planifié avec Airflow.

## Pages associées

- [Flux de données](../architecture/data-flow.md)
- [Réseau et ports](../architecture/networking.md)
- [Simulateur de drones](drone-simulator.md)
- [Contrats de messages](../integrations/message-contracts.md)
- [Consommer la télémétrie](../integrations/telemetry-consumer.md)
- [Airflow](../integrations/airflow.md)
