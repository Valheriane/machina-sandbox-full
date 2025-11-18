Bien sûr ! Voici une **nouvelle version complète du README**, déjà **mise à jour pour la nouvelle version de ton projet `machina-sandbox-full` avec le front**, tout en conservant l’esprit de l’ancien README.
Elle inclut :

✅ Backend (FastAPI)
✅ Broker MQTT (Mosquitto)
✅ Front (React + MQTT dashboard)
✅ Commandes :
– Lancer uniquement broker + backend
– Lancer toute l’application (broker + backend + front)
– Arrêter / rebuild
– Voir les logs
– Nettoyage
– Sous-chapitres clairs
– Structure du projet mise à jour

---

# 🛠️ Machina Sandbox – Full Version (Backend + Broker + Front)

Ce dépôt contient un **bac à sable complet pour tester la communication machine-to-machine (M2M)** autour d’un drone virtuel :

* **Broker MQTT** (Mosquitto)
* **Backend API** (FastAPI + SQLModel)
* **Frontend React** : dashboard pour visualiser les drones, éditer, écouter la télémétrie et envoyer des commandes.

Pensé comme base pour le projet *MachinaControl*.

---

# 📁 1) Structure du projet

```
machina-sandbox-full/
├─ docker-compose.yml
├─ README.md
│
├─ broker/
│   └─ mosquitto.conf
│
├─ backend/
│   ├─ main.py
│   ├─ models.py
│   ├─ routes/
│   ├─ Dockerfile
│   └─ requirements.txt
│
├─ agents/
│   └─ drone/
│       ├─ drone_agent.py
│       ├─ sim_models.py
│       ├─ config.py
│       ├─ security.py
│       └─ Dockerfile
│
└─ front/
    ├─ src/
    ├─ public/
    ├─ Dockerfile
    └─ vite.config.js
```

---

# 🚀 2) Pré-requis

* **Docker Desktop** (Compose v2)
* **Python 3.11** si tu veux aussi piloter les drones avec un script local
* **Node.js ≥ 18** (uniquement si tu veux lancer le front hors Docker)

---

# 📦 3) Commandes Docker

### ➤ Vérifier la configuration

```
docker compose config
```

---

# ▶️ 4) Lancer l’application

## **A) Lancer uniquement le broker + backend**

(idéal si tu testes l’API ou des agents MQTT)

```
docker compose up --build broker backend
```

Accès :

* **API** → [http://localhost:8000](http://localhost:8000)
* **Broker MQTT** → `localhost:1883` (non sécurisé)

---

## **B) Lancer l’intégralité : broker + backend + front**

```
docker compose up --build
```

Accès :

* **Frontend React** → [http://localhost:5173](http://localhost:5173)
* **Backend API** → [http://localhost:8000](http://localhost:8000)
* **Broker MQTT** → `localhost:1883`

---

# 🧹 5) Arrêter / nettoyer

### Arrêter les services :

```
docker compose down
```

### Détruire tout + volumes :

```
docker compose down -v
```

### Rebuild complet :

```
docker compose up --build --force-recreate
```

---

# 📜 6) Logs utiles

### Logs du broker (Mosquitto)

```
docker logs -f mqtt-broker
```

### Logs du backend

```
docker logs -f backend
```

### Logs du front

```
docker logs -f front
```

### Logs du drone agent

```
docker logs -f agent-drone-1
```

---

# 🔍 7) Inspecter le broker (débug MQTT)

Entrer dans le conteneur :

```
docker exec -it mqtt-broker sh
```

Ecouter tous les messages :

```
mosquitto_sub -h localhost -p 1883 -t '#' -v
```

Télémétrie (exemple drone-101) :

```
mosquitto_sub -t 'lab/drone/drone-101/telemetry' -v
```

Envoyer un message de test :

```
mosquitto_pub -t 'test' -m 'hello'
```

---

# ✈️ 8) Piloter les drones (script Python local)

Installer la lib côté host :

```
pip install paho-mqtt
```

Exemple (ping) :

```
python tools/sign_and_send_paho.py --cmd ping
```

Autres commandes disponibles :

* `--cmd takeoff --alt 20`
* `--cmd goto --lat 43.610 --lon 3.87 --alt 15`
* `--cmd land`
* `--cmd rth`

---

# 🌐 9) Frontend (React)

Le front se connecte automatiquement au broker via WebSockets (port **9001** exposé par Mosquitto).

Fonctionnalités :

* Liste des drones
* Affichage position (lat/lon/alt)
* Statut / vitesse / batterie
* Historique
* Édition d’un drone
* Envoi de commandes (via API ou MQTT direct)

Si tu veux lancer le front hors Docker :

```
cd front
npm install
npm run dev
```

---

# ⚙️ 10) Variables d’environnement importantes

### Backend

* `MQTT_HOST=broker`
* `MQTT_PORT=1883`
* `DATABASE_URL=sqlite:///db.sqlite` (ou PostgreSQL dans une version avancée)

### Agents drones

* `DRONE_ID=drone-101`
* `TOPIC_PREFIX=lab`
* `SHARED_SECRET=supersecret`
* `START_LAT=43.61`
* `START_LON=3.87`

### Front

* `VITE_MQTT_HOST=localhost`
* `VITE_MQTT_PORT=9001`

---




# README — Machina Sandbox (Drone Simulator)

Ce README rassemble **les commandes utiles** pour lancer, observer et piloter le simulateur de drone via Docker/MQTT, avec **le contexte d’exécution** de chaque commande :

* **[HOST]** = à exécuter **sur l’hôte Windows** dans PowerShell (`PS C:\machina-sandbox>`)
* **[BROKER]** = à exécuter **dans le conteneur broker** (après `docker exec -it mqtt-broker sh`)

---



---

## 2) Démarrer / arrêter l’environnement Docker

Valider la config :

```
[HOST] docker compose config
```

Lancer (build + run) :

```
[HOST] docker compose up --build
```

Voir les conteneurs qui tournent :

```
[HOST] docker ps
```

Suivre les logs :

```
[HOST] docker logs -f mqtt-broker
[HOST] docker logs -f agent-drone-1
```

Arrêter + supprimer (avec volumes) :

```
[HOST] docker compose down -v
```

> Note : l’avertissement `the attribute version is obsolete` peut être ignoré (retirez `version:` du YAML si présent).

---

## 3) Observer les messages MQTT

Entrer dans le conteneur du broker :

```
[HOST] docker exec -it mqtt-broker sh
```

Abonnement “attrape-tout” (debug) :

```
[BROKER] mosquitto_sub -h localhost -p 1883 -t '#' -v
```

Uniquement télémétrie du drone :

```
[BROKER] mosquitto_sub -h localhost -p 1883 -t 'lab/drone/drone-001/telemetry' -v
```

Événements du drone (ex: pong) :

```
[BROKER] mosquitto_sub -h localhost -p 1883 -t 'lab/drone/drone-001/events' -v
```

Message de test manuel :

```
[BROKER] mosquitto_pub -h localhost -p 1883 -t lab/test -m "hello"
```

---

## 4) Piloter le drone (script côté host)

Le drone **écoute** les commandes sur : `lab/drone/drone-001/commands`.
Les commandes sont **signées HMAC** (le script s’en charge) et le drone publie sa **télémétrie** en continu sur : `lab/drone/drone-001/telemetry`.

Script client (sur host) : `tools/sign_and_send_paho.py`

### Commandes courantes

```
[HOST] py .\tools\sign_and_send_paho.py --cmd ping
[HOST] py .\tools\sign_and_send_paho.py --cmd takeoff --alt 20
[HOST] py .\tools\sign_and_send_paho.py --cmd goto --lat 43.611 --lon 3.877 --alt 20
[HOST] py .\tools\sign_and_send_paho.py --cmd rth
[HOST] py .\tools\sign_and_send_paho.py --cmd land
```

Effets attendus :

* `ping` → event `pong` sur `.../events`
* `takeoff --alt 20` → `status: flying`, `alt ≈ 20`
* `goto` → `position.lat/lon` change progressivement, `status: flying` puis `idle` à l’arrivée
* `rth` → retour au point de départ
* `land` → `alt: 0`, `status: landing/idle`

> Remarque : un warning `DeprecationWarning: Callback API version 1...` peut s’afficher côté host. Il est sans impact (paho 1.x). On pourra migrer en paho 2.x plus tard.

---

## 5) Variables d’environnement importantes (dans docker-compose.yml)

* `DRONE_ID` : identifiant (inclus dans les topics)
* `TOPIC_PREFIX` : racine des topics (ex: `lab`)
* `MQTT_HOST`, `MQTT_PORT` : broker (dans Docker, `MQTT_HOST=broker`)
* `PUBLISH_INTERVAL_SEC` : période de publication de la télémétrie
* `SHARED_SECRET` : secret HMAC (doit **matcher** `SECRET` dans `sign_and_send_paho.py`)
* `START_LAT`, `START_LON`, `START_ALT` : point de départ

---

## 6) Dépannage rapide (FAQ)

**Q: Je ne vois rien en écoutant la télémétrie.**
R: Vérifie le bon contexte : abonne-toi **dans le broker** (`docker exec -it mqtt-broker sh`) et écoute `'#'` pour tout voir. Vérifie aussi les variables (`DRONE_ID`, `TOPIC_PREFIX`).

**Q: “Signature invalid — command rejected”.**
R: Le `SECRET` côté host doit être identique à `SHARED_SECRET` côté compose. Le script s’occupe du format JSON correct.

**Q: Le broker affiche `chown ... Read-only file system`.**
R: Warning inoffensif (montage en lecture seule). Pour le supprimer, retire `:ro` sur le volume `mosquitto.conf`.

**Q: Les commandes partent mais rien ne bouge.**
R: Regarde `docker logs -f agent-drone-1` (tu dois voir `[CMD] ...`). Active le debug publication dans `drone_agent.py` (print `[TX]`) si besoin, puis rebuild.

---

## 7) Ajouts rapides

### Ajouter un 2ᵉ drone

* Dupliquer le service `drone1` → `drone2` dans `docker-compose.yml`, changer `container_name`, `DRONE_ID` (ex: `drone-002`) et éventuellement `START_LAT/LON`.
* Rebuild & run : `[HOST] docker compose up --build`
* Topics du 2ᵉ drone : `lab/drone/drone-002/...`

### Piloter via HTTP (option)

Un petit **bridge FastAPI** peut exposer `POST /cmd` (REST) → signe et publie sur MQTT. Idéal pour éviter le script côté client.

---

## 8) Références de topics (par défaut)

* Commandes → `lab/drone/drone-001/commands`
* Télémétrie ← `lab/drone/drone-001/telemetry`
* Événements ← `lab/drone/drone-001/events`

> Modifiez `TOPIC_PREFIX` et/ou `DRONE_ID` pour changer ces chemins.

---

## 9) Commandes Docker utiles (mémo)

```
[HOST] docker compose config
[HOST] docker compose up --build
[HOST] docker compose down -v
[HOST] docker ps
[HOST] docker logs -f mqtt-broker
[HOST] docker logs -f agent-drone-1
[HOST] docker exec -it mqtt-broker sh
docker compose config
docker compose up --build
docker compose up --build backend broker
docker compose down
docker compose down -v
docker ps
docker logs -f backend
docker exec -it mqtt-broker sh
```
# 🛠️ 11) Commandes Docker (résumé mémo)

```
docker compose config
docker compose up --build
docker compose up --build backend broker
docker compose down
docker compose down -v
docker ps
docker logs -f backend
docker exec -it mqtt-broker sh
```

Bon vol ✈️
