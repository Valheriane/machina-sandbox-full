# Frontend

Le frontend fournit l’interface web de **Machina Sandbox Full**.

Il permet actuellement de gérer les drones simulés, d’envoyer des commandes et de visualiser leur télémétrie.

## Emplacement

Le frontend se trouve dans :

```text
Application/front/
```

Les principaux fichiers audités sont :

| Fichier                | Rôle                                  |
| ---------------------- | ------------------------------------- |
| `src/App.jsx`          | composition de l’interface            |
| `src/services/api.js`  | appels HTTP vers Fleet API            |
| `src/services/mqtt.js` | connexion MQTT WebSocket              |
| `public/config.js`     | configuration dynamique du navigateur |
| `Dockerfile`           | construction Vite et image Nginx      |
| `package.json`         | dépendances et commandes npm          |

## Technologies

| Technologie   | Rôle                              |
| ------------- | --------------------------------- |
| React 19      | construction de l’interface       |
| Vite 7        | développement et compilation      |
| Axios         | appels HTTP                       |
| MQTT.js       | connexion MQTT WebSocket          |
| Leaflet       | cartographie                      |
| React Leaflet | intégration de Leaflet avec React |
| Nginx         | service des fichiers statiques    |
| ESLint        | analyse du code                   |

## Composants de l’interface

L’application principale utilise notamment :

| Composant       | Rôle                            |
| --------------- | ------------------------------- |
| `DroneForm`     | création d’un drone             |
| `DroneTable`    | liste et actions sur les drones |
| `EditDroneForm` | modification d’un drone         |
| `TelemetryFeed` | affichage de la télémétrie      |
| `MapPanel`      | affichage cartographique        |
| `Modal`         | fenêtres modales                |
| `Button`        | boutons réutilisables           |

L’interface affiche également les adresses API et MQTT qu’elle utilise.

## Architecture des communications

Le frontend utilise deux canaux.

```text
Frontend
    |
    +--> HTTP avec Axios --> Fleet API
    |
    +--> MQTT WebSocket --> Broker MQTT
```

HTTP est utilisé pour gérer les drones.

MQTT WebSocket est utilisé pour recevoir les messages en temps réel.

## Configuration des URL

Le frontend utilise trois niveaux de configuration, dans cet ordre de priorité.

### 1. Configuration dynamique du navigateur

```javascript
window.__APP_CONFIG__;
```

Les propriétés recherchées sont :

```text
API_URL
MQTT_WS_URL
```

### 2. Variables Vite

```text
VITE_API_URL
VITE_MQTT_WS_URL
```

Ces variables sont intégrées lors de la construction du frontend.

### 3. Valeurs par défaut

Lorsque les autres configurations sont absentes :

```text
API HTTP : http://localhost:8000
MQTT WS  : ws://localhost:9001
```

## Configuration dynamique

Le fichier :

```text
Application/front/public/config.js
```

détermine le nom d’hôte avec :

```javascript
window.location.hostname;
```

Il construit ensuite :

```text
API_URL     : http://<hôte>:30800
MQTT_WS_URL : ws://<hôte>:30901
```

Ces ports correspondent aux NodePorts Kubernetes de :

- Fleet API ;
- MQTT WebSocket.

Exemple avec Minikube :

```text
Frontend : http://<IP_MINIKUBE>:32449
API      : http://<IP_MINIKUBE>:30800
MQTT WS  : ws://<IP_MINIKUBE>:30901
```

## Chargement de `config.js`

Le Dockerfile copie explicitement le fichier dans l’image finale :

```text
/usr/share/nginx/html/config.js
```

Le code React est prêt à lire :

```javascript
window.__APP_CONFIG__;
```

!!! warning "Chargement à confirmer"

    La présence de `config.js` dans l’image ne suffit pas à l’exécuter automatiquement.

    Le fichier HTML principal doit contenir une balise chargeant `/config.js`.

    Le fichier `index.html` n’a pas été inclus dans l’audit présenté ici. Son chargement doit donc être vérifié avant de considérer la configuration dynamique comme totalement validée.

Une vérification possible est :

```bash
grep -n "config.js" Application/front/index.html
```

## Configuration Docker Compose

En Docker Compose, les ports habituels sont :

```text
Fleet API : 8000
MQTT WS   : 9001
Frontend  : 8085 ou 8086 selon .env
```

Cependant, `public/config.js` contient les ports Kubernetes :

```text
30800
30901
```

!!! warning "Différence Compose et Kubernetes"

    Si `config.js` est chargé dans le navigateur en mode Docker Compose, il peut remplacer les valeurs locales et diriger le frontend vers :

    ```text
    localhost:30800
    localhost:30901
    ```

    Ces ports correspondent à Minikube et non au mode Compose.

    La configuration dynamique devra devenir spécifique à l’environnement ou être générée au démarrage du conteneur.

## Variables Helm

Le chart Helm injecte actuellement dans le conteneur Nginx :

```text
VITE_MQTT_URL
VITE_API_BASE
```

Le code React recherche plutôt :

```text
VITE_MQTT_WS_URL
VITE_API_URL
```

Les noms ne correspondent donc pas.

De plus, les variables `VITE_*` sont généralement utilisées lors de la phase de construction Vite, et non après le démarrage du conteneur Nginx.

!!! warning "Variables actuellement inefficaces"

    Ajouter une variable d’environnement au conteneur Nginx ne modifie pas automatiquement les fichiers JavaScript déjà compilés.

    La configuration doit être :

    - injectée pendant `npm run build` ;
    - ou fournie par un fichier dynamique comme `config.js` ;
    - ou générée au démarrage du conteneur.

## Service HTTP

Le fichier :

```text
Application/front/src/services/api.js
```

crée un client Axios avec un délai maximal de :

```text
10 secondes
```

Le frontend appelle les routes suivantes.

| Fonction      | Requête                   |
| ------------- | ------------------------- |
| `createDrone` | `POST /drones`            |
| `listDrones`  | `GET /drones`             |
| `startDrone`  | `POST /drones/{id}/start` |
| `stopDrone`   | `POST /drones/{id}/stop`  |
| `sendCmd`     | `POST /drones/{id}/cmd`   |
| `deleteDrone` | `DELETE /drones/{id}`     |
| `updateDrone` | `PATCH /drones/{id}`      |

## Création d’un drone

Le formulaire de création envoie les paramètres du drone à Fleet API.

Le modèle backend accepte notamment :

- identifiant ;
- position de départ ;
- intervalle de publication ;
- vitesse ;
- consommation ;
- bruit du cap.

La création ne démarre pas automatiquement la simulation.

## Actions sur les drones

Le tableau permet d’utiliser les opérations exposées par l’API :

- démarrer ;
- arrêter ;
- modifier ;
- supprimer ;
- envoyer une commande ;
- sélectionner un drone.

Les commandes sont transmises à Fleet API, qui les signe avant de les publier sur MQTT.

Le navigateur ne connaît donc pas directement le secret HMAC.

## Connexion MQTT WebSocket

Le service MQTT se trouve dans :

```text
Application/front/src/services/mqtt.js
```

Il tente d’importer :

```text
mqtt/dist/mqtt.min.js
```

Puis utilise l’import général `mqtt` en solution de repli.

Le code recherche ensuite une fonction `connect()` compatible avec plusieurs formes d’export du paquet.

## Paramètres MQTT

La connexion WebSocket utilise :

| Paramètre   | Valeur                     |
| ----------- | -------------------------- |
| Protocole   | `ws`                       |
| Hôte        | extrait de l’URL           |
| Port        | extrait de l’URL ou `9001` |
| Chemin      | `/`                        |
| Reconnexion | toutes les secondes        |

Le chemin `/` est explicitement utilisé pour la connexion WebSocket Mosquitto.

## Événements MQTT

Le client journalise notamment :

```text
[MQTT] connected
[MQTT] reconnecting...
[MQTT] error
```

Une reconnexion automatique est tentée toutes les :

```text
1000 millisecondes
```

## Abonnement

La fonction :

```javascript
subscribe(topic, handler);
```

permet à un composant de s’abonner à un topic.

Si le client n’est pas encore connecté, l’abonnement est différé jusqu’à l’événement :

```text
connect
```

Les messages sont interprétés comme du JSON lorsque cela est possible.

Sinon, le contenu est transmis comme une chaîne de caractères.

## Nettoyage des abonnements

La fonction `subscribe` retourne une fonction de nettoyage.

Cette fonction :

- supprime le gestionnaire de messages ;
- se désabonne du topic MQTT.

Ce mécanisme est important pour éviter de multiplier les gestionnaires lors des remontages de composants React.

## Télémétrie

Les composants :

```text
TelemetryFeed
MapPanel
```

utilisent le service MQTT.

La télémétrie attendue contient notamment :

```json
{
  "drone_id": "drone-001",
  "ts": 1710000000,
  "position": {
    "lat": 48.8566,
    "lon": 2.3522,
    "alt": 10
  },
  "speed_mps": 8,
  "battery_pct": 99,
  "status": "flying",
  "heading_deg": 90
}
```

## Carte

Le frontend utilise Leaflet et React Leaflet pour représenter les positions des drones.

Le modèle actuel est générique.

La carte ne distingue pas encore :

- les drones aériens ;
- les véhicules terrestres ;
- les drones marins ;
- les routes ;
- les zones navigables ;
- les obstacles ;
- les restrictions d’altitude.

!!! info "Évolution future"

    Une future version pourra afficher des symboles et des contraintes différents selon le domaine du véhicule :

    ```text
    air
    ground
    marine
    ```

## Construction du frontend

Le Dockerfile utilise une construction en deux étapes.

### Étape Node.js

Image :

```text
node:20-bookworm-slim
```

Opérations :

```text
npm ci
npm run build
```

Le résultat Vite est généré dans :

```text
dist/
```

### Étape Nginx

Image :

```text
nginx:1.27-alpine
```

Les fichiers compilés sont copiés dans :

```text
/usr/share/nginx/html
```

Le conteneur expose :

```text
80
```

## Configuration Nginx

Aucun fichier personnalisé `.conf` ou `.template` n’a été trouvé dans le frontend.

L’image utilise donc actuellement la configuration par défaut de Nginx.

!!! note "Application monopage"

    La configuration Nginx par défaut ne contient pas nécessairement une règle de repli vers `index.html`.

    Si un système de routes côté navigateur est ajouté plus tard, le rechargement d’une URL profonde pourra nécessiter une configuration `try_files`.

## Docker Compose

Le service Compose se nomme :

```text
front
```

L’image est construite depuis :

```text
Application/front/
```

Le port interne est :

```text
80
```

Le port hôte est défini par :

```text
MACHINA_FRONT_PORT
```

Valeur par défaut du fichier Compose :

```text
8085
```

Valeur observée dans la configuration locale :

```text
8086
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
  logs --follow --tail=100 front
```

## Kubernetes

Le chart crée :

- un Deployment `front` ;
- un Service `front`.

### Ports

| Port interne | NodePort |
| -----------: | -------: |
|         `80` |  `32449` |

### Image

```text
front:latest
```

La politique est :

```text
Never
```

L’image doit donc être construite puis chargée dans Minikube.

### Sonde de santé

Le chart ne définit actuellement aucune sonde :

- de vie ;
- de disponibilité ;
- de démarrage.

La vérification réalisée par `make devcont-check` consiste à envoyer une requête HTTP vers le NodePort du frontend.

## Commandes npm

| Commande          | Rôle                          |
| ----------------- | ----------------------------- |
| `npm run dev`     | serveur Vite de développement |
| `npm run build`   | construction de production    |
| `npm run lint`    | analyse ESLint                |
| `npm run preview` | prévisualisation du build     |

Le projet ne contient actuellement aucun script npm nommé :

```text
test
```

## Dépendances

Les dépendances principales sont déclarées avec des versions ou des plages de versions dans :

```text
package.json
```

L’installation reproductible dans le Dev Container et le Dockerfile utilise :

```bash
npm ci
```

Le fichier :

```text
package-lock.json
```

doit donc rester versionné.

## Sécurité

Le frontend se connecte actuellement avec :

```text
http://
ws://
```

Il n’utilise pas encore :

```text
https://
wss://
```

Le broker autorise également les connexions anonymes.

!!! warning "Environnement local"

    Cette configuration est adaptée à un bac à sable local.

    Elle ne doit pas être utilisée telle quelle sur un réseau exposé.

## Limites actuelles

Le frontend présente notamment les limites suivantes :

- configuration Docker Compose et Kubernetes non harmonisée ;
- variables Helm différentes des variables attendues ;
- variables Vite injectées après compilation inefficaces ;
- chargement de `config.js` à vérifier dans `index.html` ;
- NodePorts codés en dur dans `config.js` ;
- aucune configuration Nginx personnalisée ;
- aucune sonde Kubernetes ;
- aucun script de tests automatisés ;
- aucun affichage distinct pour les véhicules aériens, terrestres ou marins ;
- aucune authentification utilisateur ;
- MQTT non chiffré ;
- erreurs API principalement laissées à la gestion des composants.

## Évolutions possibles

Les améliorations pourront être réalisées progressivement :

1. vérifier le chargement de `config.js` ;
2. séparer les configurations Compose et Minikube ;
3. générer `config.js` au démarrage ;
4. supprimer ou harmoniser les variables Helm inutiles ;
5. ajouter des tests frontend ;
6. ajouter une sonde HTTP Kubernetes ;
7. ajouter une configuration Nginx explicite ;
8. différencier les types de véhicules ;
9. enrichir la carte avec les terrains et zones navigables ;
10. ajouter HTTPS, WSS et une authentification.

## Pages associées

- [Fleet API](fleet-api.md)
- [Broker MQTT](broker-mqtt.md)
- [Simulateur de drones](drone-simulator.md)
- [Réseau et ports](../architecture/networking.md)
- [Flux de données](../architecture/data-flow.md)
