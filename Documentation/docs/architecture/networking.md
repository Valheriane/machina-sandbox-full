# Réseau et ports

Cette page décrit les réseaux et les ports utilisés par **Machina Sandbox Full**.

Les valeurs dépendent du mode d’exécution :

- Docker Compose ;
- Kubernetes avec Minikube ;
- accès depuis le Dev Container ;
- accès depuis le navigateur de l’hôte.

## Vue d’ensemble

| Environnement   | Mécanisme réseau                                  |
| --------------- | ------------------------------------------------- |
| Docker Compose  | réseau Docker bridge `iotnet`                     |
| Kubernetes      | Services Kubernetes et NodePorts                  |
| Dev Container   | socket Docker de l’hôte et réseau Docker Minikube |
| Navigateur hôte | ports locaux Compose ou NodePorts Minikube        |

## Docker Compose

Le fichier :

```text
Application/docker-compose.yml
```

crée un réseau Docker nommé :

```text
iotnet
```

Les services communiquent entre eux avec leur nom Compose.

### Adresses internes

| Service          | Nom DNS interne | Port interne |
| ---------------- | --------------- | -----------: |
| Broker MQTT      | `broker`        |       `1883` |
| Broker WebSocket | `broker`        |       `9001` |
| Fleet API        | `fleet-api`     |       `8000` |
| Frontend         | `front`         |         `80` |

Fleet API utilise actuellement :

```text
MQTT_HOST=broker
MQTT_PORT=1883
```

## Ports Docker Compose exposés

| Service        | Port interne | Port hôte par défaut | Configuration locale observée |
| -------------- | -----------: | -------------------: | ----------------------------: |
| MQTT TCP       |       `1883` |               `1883` |                        `1883` |
| MQTT WebSocket |       `9001` |               `9001` |                        `9001` |
| Fleet API      |       `8000` |               `8000` |                        `8000` |
| Frontend       |         `80` |               `8085` |                        `8086` |

La configuration locale est définie dans :

```text
Application/.env
```

Pour afficher les valeurs réellement utilisées :

```bash
make compose-config
```

!!! warning "Port frontend"

    Le port par défaut du frontend est `8085` dans Docker Compose et dans `.env.example`.

    La configuration locale actuellement utilisée le surcharge à `8086`.

    La configuration CORS d’exemple référence également `8086`. Ces valeurs devront être harmonisées.

## Accès Docker Compose depuis l’hôte

Avec la configuration locale observée :

| Service        | Adresse                 |
| -------------- | ----------------------- |
| MQTT TCP       | `localhost:1883`        |
| MQTT WebSocket | `ws://localhost:9001`   |
| Fleet API      | `http://localhost:8000` |
| Frontend       | `http://localhost:8086` |

## Kubernetes

Le chart Helm définit trois Services Kubernetes :

```text
broker
fleet-api
front
```

Leur type par défaut est :

```text
NodePort
```

## Ports internes Kubernetes

À l’intérieur du cluster, les pods et Services utilisent les ports suivants :

| Service Kubernetes | Port du Service | Port du conteneur |
| ------------------ | --------------: | ----------------: |
| `broker` MQTT      |          `1883` |            `1883` |
| `broker` WebSocket |          `9001` |            `9001` |
| `fleet-api` HTTP   |          `8000` |            `8000` |
| `front` HTTP       |            `80` |              `80` |

Les services peuvent être joints avec leur nom DNS Kubernetes lorsqu’ils se trouvent dans le même namespace :

```text
broker
fleet-api
front
```

Exemples internes :

```text
broker:1883
broker:9001
fleet-api:8000
front:80
```

## NodePorts Kubernetes

| Service   | Protocole      | NodePort |
| --------- | -------------- | -------: |
| Broker    | MQTT TCP       |  `31883` |
| Broker    | MQTT WebSocket |  `30901` |
| Fleet API | HTTP           |  `30800` |
| Frontend  | HTTP           |  `32449` |

Ces ports sont accessibles avec l’adresse IP courante du nœud Minikube.

Exemple générique :

```text
http://<IP_MINIKUBE>:32449
http://<IP_MINIKUBE>:30800
ws://<IP_MINIKUBE>:30901
```

L’adresse IP ne doit pas être enregistrée comme une valeur permanente.

Pour obtenir les URL actuelles :

```bash
make devcont-status
```

## Port interne Mosquitto 9883

La configuration Kubernetes du broker contient également :

```text
listener 9883
protocol http_api
```

Le Deployment déclare le port conteneur `9883`.

Cependant, le Service Kubernetes `broker` ne publie que :

- `1883` ;
- `9001`.

Le port `9883` n’est donc pas accessible par le Service actuel.

!!! info "Port non exposé"

    La présence d’un port dans un conteneur ne signifie pas qu’il est accessible depuis les autres environnements.

    Pour être publié, il doit également être déclaré dans le Service Kubernetes ou exposé par un autre mécanisme.

## Dev Container et réseau Minikube

Le Dev Container utilise Docker-outside-of-Docker.

Cela signifie que :

- le moteur Docker fonctionne sur l’hôte ;
- le Dev Container utilise le socket Docker de l’hôte ;
- Minikube fonctionne dans un conteneur Docker de l’hôte.

Le script :

```text
.devcontainer/connect-minikube.sh
```

connecte le Dev Container au réseau Docker du conteneur Minikube.

## Étapes de connexion

Le script réalise notamment :

1. la détection du conteneur Minikube `machina` ;
2. la vérification de son état ;
3. la détection de son réseau Docker ;
4. la détection de son adresse IP ;
5. la connexion du Dev Container à ce réseau ;
6. la récupération du kubeconfig administrateur ;
7. la modification de l’adresse du serveur Kubernetes ;
8. la vérification de l’accès avec `kubectl`.

Le serveur Kubernetes est configuré sous la forme :

```text
https://<IP_MINIKUBE>:8443
```

Le nom TLS conservé est :

```text
control-plane.minikube.internal
```

## Mode strict et mode facultatif

Lors de l’ouverture du Dev Container, le script est exécuté par :

```text
postStartCommand
```

Dans ce cas, l’absence de Minikube ne bloque pas obligatoirement le Dev Container.

La cible :

```bash
make k8s-connect
```

active le mode strict.

Une erreur de connexion provoque alors l’arrêt de la commande.

## CORS

Fleet API reçoit une liste d’origines autorisées dans :

```text
CORS_ORIGINS
```

En Docker Compose, cette valeur est issue de :

```text
MACHINA_CORS_ORIGINS
```

En déploiement Minikube, `make devcont-deploy` calcule l’adresse actuelle du frontend et la transmet au chart Helm.

Exemple générique :

```text
http://<IP_MINIKUBE>:32449
```

!!! warning "Adresse dynamique"

    Comme l’adresse Minikube peut changer, la configuration CORS doit être recalculée lors du déploiement.

## Configuration frontend

Le frontend utilise dans son code :

```text
VITE_API_URL
VITE_MQTT_WS_URL
```

Les valeurs locales par défaut sont :

```text
http://localhost:8000
ws://localhost:9001
```

Le chart Helm définit actuellement d’autres noms :

```text
VITE_API_BASE
VITE_MQTT_URL
```

Cette différence doit être corrigée ou explicitement prise en charge par un mécanisme de configuration avant que les URL Kubernetes puissent être considérées comme fiables.

## Vérifications réseau

### Docker Compose

```bash
make compose-config
make compose-status
```

### Kubernetes

```bash
make k8s-status
make devcont-status
```

### Services Kubernetes

```bash
kubectl get services --namespace machina-sandbox
```

### Endpoints Kubernetes

```bash
kubectl get endpoints --namespace machina-sandbox
```

### Écoute d’un port TCP

Exemple depuis le Dev Container :

```bash
timeout 5 bash -c '</dev/tcp/<IP_MINIKUBE>/31883'
```

Remplacer `<IP_MINIKUBE>` par l’adresse affichée par :

```bash
make devcont-status
```

## Risques de conflit de ports

Docker Compose peut échouer si un port est déjà utilisé sur l’hôte.

Les ports couramment concernés sont :

```text
1883
9001
8000
8085
8086
```

Pour modifier un port Compose, utiliser :

```text
Application/.env
```

Puis valider :

```bash
make compose-config
```

## Pages associées

- [Vue générale](overview.md)
- [Flux de données](data-flow.md)
- [Docker Compose local](../getting-started/local-docker.md)
- [Dev Container et Minikube](../getting-started/devcontainer-minikube.md)
