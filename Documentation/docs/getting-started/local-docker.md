# Docker Compose local

Cette page décrit comment exécuter les composants principaux de **Machina Sandbox Full** avec Docker Compose, sans utiliser Kubernetes, Minikube ou Helm.

Ce mode est adapté pour :

- découvrir l’application ;
- développer les services localement ;
- tester les communications entre les composants ;
- reconstruire rapidement les images ;
- consulter les logs sans administrer un cluster Kubernetes.

## Services disponibles

Le fichier Docker Compose se trouve dans :

```text
Application/docker-compose.yml
```

Il déclare actuellement trois services :

| Service Compose | Rôle                           | Construction                                     |
| --------------- | ------------------------------ | ------------------------------------------------ |
| `broker`        | Broker MQTT Mosquitto          | Image `eclipse-mosquitto:2`                      |
| `fleet-api`     | API de gestion de la flotte    | Image construite depuis `Application/fleet-api/` |
| `front`         | Interface web servie par Nginx | Image construite depuis `Application/front/`     |

!!! info "Simulateur de drones"

    Le simulateur situé dans `Application/agents/drone/` n’est actuellement pas déclaré comme service dans `Application/docker-compose.yml`.

    Le démarrage de Docker Compose lance donc le broker, Fleet API et le frontend, mais pas automatiquement un simulateur de drone.

## Architecture du mode Compose

Les trois services partagent un réseau Docker privé nommé :

```text
iotnet
```

Le flux principal est organisé de la manière suivante :

```text
Navigateur
    |
    +--> Frontend
    |
    +--> Fleet API
             |
             v
        Broker MQTT
```

Dans le réseau Docker :

- Fleet API contacte le broker avec le nom d’hôte `broker` ;
- le port MQTT interne utilisé par Fleet API est `1883` ;
- le frontend dépend de Fleet API et du broker au niveau de l’ordre de démarrage.

!!! warning "Dépendance et disponibilité"

    Les directives `depends_on` contrôlent l’ordre de création des conteneurs.

    Elles ne garantissent pas que le broker ou Fleet API soient déjà complètement disponibles lorsque le service suivant démarre.

    Le fichier Compose ne définit actuellement aucun contrôle de santé Docker explicite.

## Prérequis

Avant de lancer l’application, vérifier que Docker fonctionne :

```bash
docker --version
docker info
docker compose version
```

Le projet utilise la commande moderne :

```text
docker compose
```

et non l’ancienne commande séparée `docker-compose`.

Les commandes présentées dans cette page doivent être lancées depuis la racine du dépôt :

```text
machina-sandbox-full/
```

Elles peuvent être exécutées :

- depuis le terminal Linux hôte ;
- ou depuis le Dev Container, qui utilise le moteur Docker de l’hôte.

## Configuration locale

Les variables locales sont chargées depuis :

```text
Application/.env
```

Ce fichier est ignoré par Git et ne doit pas contenir de secret destiné à un environnement réel.

Un modèle est fourni dans :

```text
Application/.env.example
```

Lorsqu’aucun fichier `.env` n’existe encore, il peut être créé à partir du modèle :

```bash
test -f Application/.env || cp Application/.env.example Application/.env
```

Il faut ensuite vérifier son contenu avant de démarrer l’application.

!!! danger "Secrets"

    La variable `MACHINA_SHARED_SECRET` est utilisée pour le développement local.

    Ne publie jamais une valeur sensible dans Git, dans la documentation ou dans une capture d’écran.

    La valeur d’exemple ne doit pas être utilisée dans un environnement exposé ou en production.

## Variables principales

| Variable                | Rôle                                         |  Valeur par défaut dans Compose |
| ----------------------- | -------------------------------------------- | ------------------------------: |
| `MACHINA_MQTT_PORT`     | Port MQTT TCP exposé sur l’hôte              |                          `1883` |
| `MACHINA_MQTT_WS_PORT`  | Port MQTT WebSocket exposé sur l’hôte        |                          `9001` |
| `MACHINA_API_PORT`      | Port HTTP de Fleet API                       |                          `8000` |
| `MACHINA_FRONT_PORT`    | Port HTTP du frontend                        |                          `8085` |
| `MACHINA_CORS_ORIGINS`  | Origines autorisées par Fleet API            |            configuration locale |
| `MACHINA_SHARED_SECRET` | Secret partagé de développement              |         valeur de développement |
| `HOST_PROJECT_PATH`     | Chemin hôte utilisé pour les montages Docker | déterminé selon l’environnement |

La configuration locale actuellement utilisée sur la machine de développement surcharge le frontend sur le port :

```text
8086
```

!!! warning "Port du frontend à harmoniser"

    Le fichier Compose et `.env.example` déclarent actuellement `8085` comme port par défaut du frontend.

    La configuration CORS fournie dans `.env.example` référence cependant le port `8086`.

    Cette différence doit être harmonisée ultérieurement. En attendant, la commande `make compose-config` permet de vérifier la configuration réellement active.

## Valider la configuration

Avant tout démarrage :

```bash
make compose-config
```

Cette commande :

1. charge les variables présentes dans `Application/.env` ;
2. interprète `Application/docker-compose.yml` ;
3. vérifie la syntaxe de la configuration ;
4. affiche les ports actuellement utilisés.

Une configuration valide produit notamment :

```text
Configuration Docker Compose valide.
```

La commande ne démarre aucun conteneur.

## Démarrer l’application

Pour construire les images et démarrer les trois services :

```bash
make compose-up
```

Cette commande exécute d’abord la validation de la configuration, puis lance l’équivalent de :

```text
docker compose up -d --build
```

L’option `--build` reconstruit les images de Fleet API et du frontend lorsque cela est nécessaire.

L’option `-d` laisse les conteneurs fonctionner en arrière-plan.

## Vérifier l’état des services

Après le démarrage :

```bash
make compose-status
```

La commande affiche :

- le nom des services ;
- l’état des conteneurs ;
- les ports publiés ;
- les URL principales de Fleet API et du frontend.

Il est également possible de vérifier directement les conteneurs Docker :

```bash
docker ps
```

!!! note "Démarrage asynchrone"

    `make compose-up` rend la main après le démarrage des conteneurs.

    Fleet API ou le frontend peuvent avoir besoin de quelques secondes supplémentaires avant d’être accessibles.

    Consulte les logs si un service ne répond pas immédiatement.

## Accéder aux services

Avec la configuration locale actuellement active :

| Service        | Accès depuis l’hôte     |
| -------------- | ----------------------- |
| MQTT TCP       | `localhost:1883`        |
| MQTT WebSocket | `localhost:9001`        |
| Fleet API      | `http://localhost:8000` |
| Frontend       | `http://localhost:8086` |

Ces valeurs peuvent être modifiées dans `Application/.env`.

Pour afficher les valeurs réellement prises en compte :

```bash
make compose-config
```

## Consulter les logs

Pour suivre les logs de tous les services :

```bash
make compose-logs
```

La commande affiche les 100 dernières lignes, puis continue à suivre les nouveaux messages.

Pour quitter le suivi sans arrêter les conteneurs :

```text
Ctrl+C
```

### Consulter un seul service

Le Makefile ne fournit pas actuellement de cible dédiée par service.

Pour un diagnostic ponctuel, il est possible d’utiliser directement Docker Compose :

```bash
docker compose \
  --project-directory Application \
  -f Application/docker-compose.yml \
  logs --follow --tail=100 fleet-api
```

Remplacer `fleet-api` par l’un des services suivants :

```text
broker
fleet-api
front
```

## Redémarrer les services

Pour redémarrer les conteneurs existants sans reconstruire les images :

```bash
make compose-restart
```

Cette commande est utile après une interruption temporaire.

!!! note "Reconstruction des images"

    `make compose-restart` ne reconstruit pas les images.

    Après une modification du code ou du Dockerfile, utiliser plutôt :

    ```bash
    make compose-up
    ```

    La cible `compose-up` utilise l’option `--build`.

## Arrêter l’application

Pour arrêter et supprimer les conteneurs et le réseau Compose :

```bash
make compose-down
```

Cette commande ne supprime pas les fichiers persistants montés depuis le dépôt.

Elle ne supprime notamment pas automatiquement :

- la base SQLite de Fleet API ;
- les données du broker présentes dans son dossier monté.

## Données persistantes

### Fleet API

Fleet API utilise une base SQLite configurée avec :

```text
sqlite:///data/fleet.db
```

Le dossier du conteneur `/app/data` est lié à :

```text
Application/fleet-api/data/
```

Les données peuvent donc rester présentes après `make compose-down`.

### Broker MQTT

Le broker monte sa configuration depuis :

```text
Application/broker/mosquitto.conf
```

Son répertoire de données est lié à :

```text
Application/broker/
```

!!! warning "Suppression manuelle"

    `make compose-down` ne supprime pas ces fichiers persistants.

    Ne supprime pas une base ou les données MQTT sans les inspecter et sans vérifier qu’elles ne sont plus nécessaires.

## Configuration interne des services

### Broker MQTT

Le broker publie deux ports internes :

| Port interne | Usage          |
| -----------: | -------------- |
|       `1883` | MQTT TCP       |
|       `9001` | MQTT WebSocket |

Sa configuration est montée en lecture seule dans le conteneur.

### Fleet API

Fleet API reçoit notamment les variables internes suivantes :

| Variable interne | Valeur en mode Compose                         |
| ---------------- | ---------------------------------------------- |
| `MQTT_HOST`      | `broker`                                       |
| `MQTT_PORT`      | `1883`                                         |
| `TOPIC_PREFIX`   | `lab`                                          |
| `DATABASE_URL`   | `sqlite:///data/fleet.db`                      |
| `SHARED_SECRET`  | valeur issue de la configuration locale        |
| `CORS_ORIGINS`   | origines définies dans la configuration locale |

### Frontend

Le frontend est construit depuis :

```text
Application/front/
```

Son image utilise Nginx pour exposer l’application web sur le port interne `80`.

Le port disponible sur l’hôte est défini par :

```text
MACHINA_FRONT_PORT
```

## Vérifications courantes

### Vérifier la configuration sans démarrer

```bash
make compose-config
```

### Construire et démarrer

```bash
make compose-up
```

### Afficher l’état

```bash
make compose-status
```

### Suivre les logs

```bash
make compose-logs
```

### Redémarrer sans reconstruire

```bash
make compose-restart
```

### Arrêter

```bash
make compose-down
```

## Différences avec Minikube

| Docker Compose                            | Minikube et Helm                                        |
| ----------------------------------------- | ------------------------------------------------------- |
| Exécute directement des conteneurs Docker | Exécute des pods Kubernetes                             |
| Utilise `Application/docker-compose.yml`  | Utilise `Application/machina-sandbox/`                  |
| Expose les ports sur `localhost`          | Expose les services avec des NodePorts                  |
| Ne nécessite pas de cluster Kubernetes    | Nécessite le profil Minikube `machina`                  |
| Démarrage rapide                          | Environnement plus proche de l’orchestration Kubernetes |
| Trois services déclarés                   | Trois services déployés avec Helm                       |
| Pas de release Helm                       | Release `machina-sandbox`                               |

Les deux modes sont indépendants. Il n’est pas nécessaire de démarrer Minikube pour utiliser Docker Compose.

!!! warning "Conflits de ports"

    Docker Compose et d’autres processus locaux peuvent tenter d’utiliser les mêmes ports.

    Si un port est déjà occupé, modifie sa valeur dans `Application/.env`, puis relance :

    ```bash
    make compose-config
    ```

## Dépannage rapide

### Aucun conteneur n’apparaît

Vérifier d’abord :

```bash
make compose-status
```

Puis relancer :

```bash
make compose-up
```

### Un service s’arrête immédiatement

Consulter les logs :

```bash
make compose-logs
```

### La configuration est invalide

Exécuter :

```bash
make compose-config
```

Puis vérifier :

- `Application/docker-compose.yml` ;
- `Application/.env` ;
- les chemins de montage ;
- les ports déjà utilisés.

### Le frontend n’est pas accessible

Vérifier le port actif affiché par :

```bash
make compose-config
```

Ne pas supposer qu’il utilise systématiquement `8085` ou `8086`, car la valeur peut être surchargée dans `.env`.

## Étape suivante

Pour consulter l’inventaire de toutes les commandes disponibles :

[Commandes disponibles](commands.md)

Pour utiliser Kubernetes :

[Dev Container et Minikube](devcontainer-minikube.md)
