# Ajouter un service

Cette page décrit une méthode progressive pour intégrer un nouveau service dans **Machina Sandbox Full**.

Un nouveau service peut être, par exemple :

- un consommateur de télémétrie MQTT ;
- un service spécialisé dans les données GPS ;
- un processeur de données IoT ;
- une API complémentaire ;
- un service d’archivage ;
- un composant de monitoring ;
- une expérimentation autour d’Airflow.

!!! info "Intégration progressive"

    Un service n’a pas besoin d’être ajouté immédiatement à tous les environnements.

    Une première version peut fonctionner localement, puis être intégrée successivement à Docker Compose, Helm, la CI et l’observabilité.

## Objectifs

L’intégration d’un service doit préserver :

- la lisibilité du dépôt ;
- l’isolation des dépendances ;
- la cohérence des configurations ;
- la sécurité des secrets ;
- la stabilité des contrats de messages ;
- la reproductibilité des environnements ;
- la validation Docker et Kubernetes ;
- la documentation du projet.

## Étapes générales

L’ajout d’un service peut suivre cet ordre :

1. définir sa responsabilité ;
2. choisir son emplacement ;
3. créer une version minimale exécutable ;
4. définir sa configuration ;
5. ajouter ses tests ;
6. l’intégrer à Docker Compose ;
7. ajouter ses contrôles de santé ;
8. l’intégrer au chart Helm ;
9. mettre à jour les validations ;
10. compléter la documentation ;
11. ajouter l’observabilité ;
12. préparer la CI.

## 1. Définir la responsabilité du service

Avant de créer des fichiers, préciser ce que le service doit faire.

Questions utiles :

- Quel problème résout-il ?
- Quels messages reçoit-il ?
- Quels messages produit-il ?
- Expose-t-il une API HTTP ?
- A-t-il besoin d’une base de données ?
- Doit-il fonctionner en temps réel ?
- Réalise-t-il plutôt des traitements périodiques ?
- Doit-il être déployé avec l’application principale ?
- Peut-il fonctionner indépendamment ?
- Quelles données doit-il conserver ?

!!! warning "Une responsabilité claire"

    Éviter de regrouper dans un même service des responsabilités sans lien direct.

    Un consommateur GPS, un moteur d’alertes et un traitement périodique Airflow peuvent partager les mêmes données, mais ne remplissent pas nécessairement la même fonction.

## Exemple : consommateur GPS

Responsabilité possible :

```text
Recevoir les positions MQTT des drones, les valider et les enregistrer.
```

Entrée :

```text
lab/drone/+/telemetry
```

ou, après évolution du contrat :

```text
lab/drone/+/telemetry/gps
```

Sorties possibles :

- enregistrement en base ;
- métriques ;
- événements d’anomalie ;
- API de consultation.

## 2. Choisir l’emplacement

Les services applicatifs sont regroupés dans :

```text
Application/
```

Un nouveau service pourrait être créé dans :

```text
Application/telemetry-consumer/
```

Exemple :

```text
Application/
├── agents/
├── broker/
├── fleet-api/
├── front/
├── machina-sandbox/
└── telemetry-consumer/
```

!!! note "Nom du dossier"

    Utiliser un nom court, explicite et stable.

    Éviter un nom trop générique comme `service`, `backend2` ou `test`.

## 3. Créer une structure minimale

Pour un service Python :

```text
Application/telemetry-consumer/
├── consumer.py
├── config.py
├── requirements.txt
├── Dockerfile
├── tests/
│   └── test_consumer.py
└── README.md
```

Pour un service exposant une API :

```text
Application/telemetry-consumer/
├── main.py
├── config.py
├── models.py
├── requirements.txt
├── Dockerfile
├── tests/
└── README.md
```

Pour un service Node.js :

```text
Application/example-service/
├── src/
├── package.json
├── package-lock.json
├── Dockerfile
└── README.md
```

## 4. Isoler les dépendances

Chaque service doit gérer ses propres dépendances.

### Service Python

Créer :

```text
requirements.txt
```

et un environnement virtuel propre au service :

```text
Application/telemetry-consumer/.venv/
```

Exemple :

```bash
python3 -m venv Application/telemetry-consumer/.venv
Application/telemetry-consumer/.venv/bin/python \
  -m pip install \
  -r Application/telemetry-consumer/requirements.txt
```

### Service Node.js

Le service doit posséder :

```text
package.json
package-lock.json
```

L’installation reproductible utilise :

```bash
npm ci
```

!!! warning "Ne pas partager les environnements"

    Un nouveau service Python ne doit pas réutiliser l’environnement virtuel de Fleet API.

    Chaque service doit pouvoir faire évoluer ses dépendances indépendamment.

## 5. Définir la configuration

La configuration doit être fournie par des variables d’environnement.

Exemple pour un consommateur MQTT :

| Variable         | Exemple                 | Rôle                |
| ---------------- | ----------------------- | ------------------- |
| `MQTT_HOST`      | `broker`                | nom du broker       |
| `MQTT_PORT`      | `1883`                  | port MQTT           |
| `MQTT_TOPIC`     | `lab/drone/+/telemetry` | abonnement          |
| `MQTT_CLIENT_ID` | `telemetry-consumer`    | identifiant MQTT    |
| `LOG_LEVEL`      | `INFO`                  | niveau de logs      |
| `DATABASE_URL`   | selon stockage          | connexion à la base |

Le code peut fournir des valeurs adaptées au développement local, mais pas de secret réel.

## Secrets

Les secrets ne doivent pas être placés dans :

- le code source ;
- le Dockerfile ;
- `docker-compose.yml` ;
- le chart Helm en clair pour un environnement réel ;
- les pages MkDocs ;
- les logs ;
- les captures d’écran.

Exemples de secrets :

```text
MQTT_PASSWORD
SHARED_SECRET
DATABASE_PASSWORD
API_TOKEN
```

!!! danger "Valeurs de développement"

    Les valeurs comme `dev-secret-change-me` sont uniquement des valeurs de démonstration.

    Elles ne constituent pas une gestion sécurisée des secrets.

## 6. Ajouter un fichier d’exemple

Les variables non sensibles peuvent être documentées dans un fichier comme :

```text
.env.example
```

Exemple :

```dotenv
MQTT_HOST=localhost
MQTT_PORT=1883
MQTT_TOPIC=lab/drone/+/telemetry
MQTT_CLIENT_ID=machina-telemetry-consumer
LOG_LEVEL=INFO
```

Ne jamais ajouter une valeur réelle de mot de passe dans ce fichier.

## 7. Ajouter un Dockerfile

Exemple conceptuel pour un service Python :

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt ./

RUN pip install \
    --no-cache-dir \
    -r requirements.txt

COPY . .

CMD ["python", "-u", "consumer.py"]
```

## Bonnes pratiques Docker

Le Dockerfile doit autant que possible :

- utiliser une image de base précise ;
- installer uniquement les dépendances nécessaires ;
- éviter de copier les fichiers inutiles ;
- ne contenir aucun secret ;
- produire des logs sur la sortie standard ;
- utiliser une commande de démarrage explicite ;
- prévoir un utilisateur non privilégié dans une future version durcie.

!!! note "Image de développement ou image stable"

    Fleet API utilise actuellement `uvicorn --reload`, ce qui correspond à un usage de développement.

    Pour un nouveau service, distinguer dès que possible le mode de développement du mode d’exécution stable.

## 8. Ajouter un `.dockerignore`

Un nouveau service peut inclure :

```text
.venv/
__pycache__/
.pytest_cache/
*.pyc
.env
tests/
```

Le contenu exact dépend de ce qui doit être inclus dans l’image.

Les tests peuvent être conservés dans une image dédiée de CI, tout en étant exclus de l’image d’exécution finale.

## 9. Tester l’image seule

Avant Docker Compose :

```bash
docker build \
  --tag telemetry-consumer:dev \
  Application/telemetry-consumer
```

Vérifier ensuite l’image :

```bash
docker image inspect telemetry-consumer:dev
```

Le service peut être lancé ponctuellement avec les variables nécessaires.

Exemple conceptuel :

```bash
docker run --rm \
  --env MQTT_HOST=host.docker.internal \
  --env MQTT_PORT=1883 \
  --env MQTT_TOPIC='lab/drone/+/telemetry' \
  telemetry-consumer:dev
```

L’adresse exacte dépend de l’environnement Docker utilisé.

## 10. Intégrer le service à Docker Compose

Le fichier principal est :

```text
Application/docker-compose.yml
```

Exemple conceptuel :

```yaml
services:
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

!!! warning "Exemple non encore implémenté"

    Ce bloc ne fait pas partie du fichier Compose actuel.

    Il doit être adapté aux besoins réels du futur service.

## Réseau Compose

Le service doit rejoindre le réseau existant :

```text
iotnet
```

Il peut alors joindre le broker avec :

```text
broker:1883
```

Il ne faut pas utiliser `localhost` pour joindre un autre conteneur.

Dans un conteneur, `localhost` représente le conteneur lui-même.

## Dépendances Compose

Un consommateur MQTT dépend généralement du broker :

```yaml
depends_on:
  - broker
```

Cependant, `depends_on` ne garantit pas que Mosquitto soit déjà prêt à accepter une connexion.

Le service doit gérer :

- les échecs de connexion ;
- les reconnexions ;
- un délai progressif ;
- les interruptions temporaires.

## Contrôle de santé Compose

Le fichier Compose actuel ne contient pas encore de contrôles de santé.

Un nouveau service exposant une route HTTP pourrait définir :

```yaml
healthcheck:
  test:
    - CMD
    - python
    - -c
    - >-
      import urllib.request;
      urllib.request.urlopen('http://localhost:8000/health')
  interval: 10s
  timeout: 3s
  retries: 5
```

Ce bloc doit être adapté au port et à la technologie du service.

## Service sans API HTTP

Un consommateur MQTT n’a pas obligatoirement besoin d’exposer un port.

Il peut fonctionner uniquement comme processus en arrière-plan.

Cependant, une petite API interne peut être utile pour exposer :

```text
/health
/ready
/metrics
```

## Valider Docker Compose

Après modification :

```bash
make compose-config
```

Cette commande doit réussir avant de démarrer les services.

Puis :

```bash
make compose-up
make compose-status
```

Consulter les logs :

```bash
docker compose \
  --project-directory Application \
  -f Application/docker-compose.yml \
  logs --follow --tail=100 telemetry-consumer
```

## 11. Définir la santé et la disponibilité

Un service devrait distinguer autant que possible :

### Santé

```text
/health
```

Le processus fonctionne et sa boucle principale n’est pas bloquée.

### Disponibilité

```text
/ready
```

Le service est capable de réaliser sa fonction principale.

Pour un consommateur MQTT, `/ready` peut vérifier :

- la connexion au broker ;
- l’accès au stockage ;
- la capacité de la file interne ;
- l’état du worker de traitement.

!!! warning "Ne pas redémarrer pour toute panne externe"

    Une perte temporaire de connexion MQTT ne signifie pas toujours que le processus doit être redémarré.

    La sonde de vie doit rester différente de la sonde de disponibilité.

## 12. Ajouter le service au chart Helm

Le chart principal se trouve dans :

```text
Application/machina-sandbox/
```

Un service peut nécessiter :

```text
templates/telemetry-consumer-deployment.yaml
templates/telemetry-consumer-service.yaml
templates/telemetry-consumer-configmap.yaml
```

Le Service Kubernetes n’est nécessaire que si le composant expose un port accessible par d’autres pods.

Un consommateur MQTT sans API peut avoir uniquement un Deployment.

## Ajouter les valeurs Helm

Exemple conceptuel dans `values.yaml` :

```yaml
telemetryConsumer:
  enabled: true
  replicas: 1

  image:
    repository: telemetry-consumer
    tag: latest
    pullPolicy: Never

  mqtt:
    host: broker
    port: "1883"
    topic: lab/drone/+/telemetry

  health:
    port: 8080
```

## Deployment conceptuel

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: telemetry-consumer

spec:
  replicas: { { .Values.telemetryConsumer.replicas } }

  selector:
    matchLabels:
      app: telemetry-consumer

  template:
    metadata:
      labels:
        app: telemetry-consumer

    spec:
      containers:
        - name: telemetry-consumer
          image: >-
            {{ .Values.telemetryConsumer.image.repository }}:
            {{- .Values.telemetryConsumer.image.tag }}

          imagePullPolicy: >-
            {{ .Values.telemetryConsumer.image.pullPolicy }}

          env:
            - name: MQTT_HOST
              value: { { .Values.telemetryConsumer.mqtt.host | quote } }

            - name: MQTT_PORT
              value: { { .Values.telemetryConsumer.mqtt.port | quote } }

            - name: MQTT_TOPIC
              value: { { .Values.telemetryConsumer.mqtt.topic | quote } }
```

!!! note "Exemple de structure"

    Ce template est illustratif.

    Il doit être ajusté puis validé avec Helm et kubeconform avant son utilisation.

## Images Minikube

Le parcours actuel construit les images puis les charge dans le conteneur Minikube.

Le nouveau service devra être ajouté à :

```text
devcont-build-images
```

Exemple conceptuel :

```make
docker build \
  --tag telemetry-consumer:latest \
  $(APPLICATION_DIR)/telemetry-consumer
```

Il faudra également ajouter l’image à :

```text
devcont-load-images
```

Le chargement actuel utilise :

```text
docker save
docker exec ... docker load
```

Oublier cette étape provoquera généralement une erreur de type :

```text
ImagePullBackOff
```

lorsque la politique Helm est :

```text
Never
```

## 13. Valider le chart Helm

Après toute modification du chart :

```bash
make validate-k8s
```

Cette commande vérifie :

1. `helm lint` ;
2. `helm template` ;
3. kubeconform.

La génération doit produire le nombre de ressources attendu.

Il faut vérifier qu’une nouvelle ressource n’a pas été ajoutée ou oubliée par erreur.

## Afficher les manifests générés

Le Makefile écrit actuellement les manifests dans :

```text
/tmp/machina-rendered.yaml
```

Ils peuvent être inspectés avec :

```bash
sed -n '1,320p' /tmp/machina-rendered.yaml
```

Pour rechercher le nouveau service :

```bash
grep -n "telemetry-consumer" \
  /tmp/machina-rendered.yaml
```

## 14. Déployer dans Minikube

Après validation :

```bash
make devcont-deploy
```

Puis vérifier :

```bash
kubectl get deployments,pods,services \
  --namespace machina-sandbox
```

Consulter les logs :

```bash
kubectl logs \
  --namespace machina-sandbox \
  deployment/telemetry-consumer \
  --follow
```

## Probes Kubernetes

Exemple conceptuel :

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: health
  initialDelaySeconds: 2
  periodSeconds: 5

livenessProbe:
  httpGet:
    path: /health
    port: health
  initialDelaySeconds: 10
  periodSeconds: 10
```

Les valeurs doivent être adaptées au temps réel de démarrage du service.

## Ressources Kubernetes

Un nouveau Deployment devrait progressivement définir :

```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi

  limits:
    cpu: 500m
    memory: 256Mi
```

Ces valeurs doivent être mesurées et non choisies comme limites définitives sans observation.

## 15. Gérer les secrets Kubernetes

Un secret ne doit pas être placé directement dans `values.yaml` pour un environnement réel.

Une future solution peut utiliser :

- un Secret Kubernetes ;
- un gestionnaire de secrets ;
- Sealed Secrets ;
- External Secrets ;
- les secrets du système de déploiement.

Exemple de référence :

```yaml
env:
  - name: MQTT_PASSWORD
    valueFrom:
      secretKeyRef:
        name: telemetry-consumer-secrets
        key: mqtt-password
```

La création et le chiffrement du Secret doivent être définis séparément.

## 16. Ajouter des tests

Un nouveau service doit posséder au minimum des tests pour ses responsabilités principales.

Pour un consommateur de télémétrie :

- payload valide ;
- JSON invalide ;
- champ absent ;
- coordonnées invalides ;
- batterie hors limites ;
- reconnexion MQTT ;
- erreur de stockage ;
- plusieurs drones ;
- arrêt propre du processus.

## Tests unitaires

Ils peuvent vérifier :

- la validation du payload ;
- l’extraction de l’identifiant depuis le topic ;
- les transformations ;
- la gestion des erreurs ;
- la sérialisation.

## Tests d’intégration

Ils peuvent vérifier :

```text
Simulateur
    |
    v
Broker MQTT
    |
    v
Nouveau service
```

Ces tests peuvent être plus longs et nécessiter Docker Compose.

Ils doivent être séparés des tests unitaires rapides.

## 17. Intégrer la CI

Le workflow GitHub Actions se trouve dans :

```text
.github/workflows/ci.yml
```

Avant de le modifier, inspecter ses jobs, ses chemins et les technologies déjà prises en charge.

Un nouveau service Python pourrait nécessiter :

- l’installation de Python ;
- l’installation des dépendances ;
- `pip check` ;
- les tests ;
- une analyse statique ;
- la construction de l’image Docker.

Un service Node.js pourrait nécessiter :

- Node.js ;
- `npm ci` ;
- `npm run lint` ;
- `npm run build` ;
- les tests lorsqu’ils existent.

!!! warning "Ne pas copier aveuglément un job"

    Le workflow actuel contient des validations adaptées à Fleet API et au frontend.

    Le nouveau job doit correspondre à la structure et aux dépendances réelles du nouveau service.

## Filtrage par chemins

Un job peut être exécuté seulement lorsque certains chemins changent.

Exemple conceptuel :

```text
Application/telemetry-consumer/**
.github/workflows/ci.yml
```

Les règles exactes dépendent de la structure du workflow actuel.

## Validations globales

Un changement de service peut également nécessiter :

```bash
make compose-config
make validate-k8s
make docs-check
```

Ces validations couvrent respectivement :

- Docker Compose ;
- Helm et Kubernetes ;
- la documentation.

## 18. Ajouter l’observabilité

Le service doit écrire ses logs sur :

```text
stdout
stderr
```

Il ne doit pas dépendre uniquement d’un fichier local dans son conteneur.

## Logs recommandés

Journaliser :

- démarrage du service ;
- configuration non sensible ;
- connexion MQTT ;
- abonnement ;
- reconnexion ;
- messages invalides ;
- erreurs de traitement ;
- arrêt du service.

Ne pas journaliser :

- secrets ;
- mots de passe ;
- tokens ;
- payloads complets sans nécessité ;
- données sensibles.

## Métriques possibles

Pour un consommateur MQTT :

```text
messages_received_total
messages_processed_total
messages_invalid_total
processing_errors_total
processing_duration_seconds
queue_size
mqtt_connected
last_message_timestamp
```

Les noms définitifs devront suivre une convention commune au projet.

## Traces futures

Une future évolution peut ajouter un identifiant de corrélation ou un `message_id`.

Cela permettrait de suivre un message depuis :

```text
Drone
→ Broker
→ Consommateur
→ Stockage
→ Traitement Airflow
```

Le contrat actuel ne fournit pas encore cet identifiant.

## 19. Mettre à jour la documentation

L’ajout d’un service doit entraîner une mise à jour de plusieurs pages.

### Page du service

Créer par exemple :

```text
Documentation/docs/services/telemetry-consumer.md
```

La page doit présenter :

- son rôle ;
- son emplacement ;
- ses technologies ;
- sa configuration ;
- ses entrées et sorties ;
- ses ports ;
- ses dépendances ;
- ses probes ;
- ses commandes de test ;
- ses limites.

### Architecture

Mettre à jour si nécessaire :

```text
architecture/overview.md
architecture/data-flow.md
architecture/networking.md
architecture/environments.md
```

### Intégrations

Mettre à jour :

```text
integrations/message-contracts.md
integrations/telemetry-consumer.md
```

### Exploitation

Mettre à jour :

```text
operations/logging.md
operations/monitoring.md
operations/troubleshooting.md
```

### Navigation MkDocs

Ajouter la nouvelle page dans :

```text
Documentation/mkdocs.yml
```

Puis valider :

```bash
make docs-check
```

## 20. Mettre à jour le Makefile

Une nouvelle cible n’est utile que si elle simplifie une opération répétée.

Exemples possibles :

```text
telemetry-install
telemetry-test
telemetry-run
```

Éviter de créer une cible pour chaque commande ponctuelle.

Les commandes principales du projet doivent rester découvrables avec :

```bash
make help
```

## 21. Préparer Git et les commits

Le service peut être intégré par petits commits thématiques.

Exemple :

```text
feat(telemetry): add MQTT telemetry consumer
```

Puis :

```text
build(compose): integrate telemetry consumer
```

Puis :

```text
feat(helm): deploy telemetry consumer
```

Puis :

```text
test(telemetry): cover payload validation
```

Puis :

```text
docs(services): document telemetry consumer
```

Cette séparation facilite :

- la revue ;
- les retours en arrière ;
- la compréhension de l’historique ;
- le diagnostic d’une régression.

## 22. Vérifications avant commit

### État Git

```bash
git status --short
```

### Erreurs de format dans le diff

```bash
git diff --check
```

### Tests du service

Exemple conceptuel :

```bash
Application/telemetry-consumer/.venv/bin/python \
  -m pytest \
  Application/telemetry-consumer/tests
```

### Docker Compose

```bash
make compose-config
```

### Kubernetes

```bash
make validate-k8s
```

### Documentation

```bash
make docs-check
```

## Liste de contrôle

### Développement

- [ ] responsabilité du service définie ;
- [ ] dossier propre créé ;
- [ ] dépendances isolées ;
- [ ] configuration par variables d’environnement ;
- [ ] aucun secret versionné ;
- [ ] arrêt propre du processus ;
- [ ] gestion des erreurs ;
- [ ] tests ajoutés.

### Docker

- [ ] Dockerfile créé ;
- [ ] `.dockerignore` vérifié ;
- [ ] image construite ;
- [ ] logs visibles ;
- [ ] aucun secret dans l’image.

### Docker Compose

- [ ] service ajouté ;
- [ ] réseau `iotnet` utilisé ;
- [ ] dépendances définies ;
- [ ] variables documentées ;
- [ ] `make compose-config` valide ;
- [ ] démarrage vérifié ;
- [ ] arrêt vérifié.

### Kubernetes et Helm

- [ ] valeurs Helm ajoutées ;
- [ ] Deployment créé ;
- [ ] Service ajouté seulement si nécessaire ;
- [ ] ConfigMap ou Secret utilisés correctement ;
- [ ] probes définies ;
- [ ] image chargée dans Minikube ;
- [ ] `make validate-k8s` valide ;
- [ ] déploiement vérifié.

### Qualité

- [ ] tests unitaires ;
- [ ] tests d’intégration si nécessaires ;
- [ ] CI mise à jour ;
- [ ] erreurs de lint corrigées ;
- [ ] versions des dépendances maîtrisées.

### Documentation

- [ ] page du service créée ;
- [ ] navigation MkDocs mise à jour ;
- [ ] architecture mise à jour ;
- [ ] contrats mis à jour ;
- [ ] commandes documentées ;
- [ ] limites clairement indiquées ;
- [ ] `make docs-check` valide.

## Exemple de parcours minimal

Pour expérimenter rapidement un consommateur MQTT :

1. créer `Application/telemetry-consumer/` ;
2. écrire un consommateur qui affiche les messages ;
3. tester avec le broker local ;
4. ajouter le service à Compose ;
5. valider avec `make compose-config` ;
6. démarrer avec `make compose-up` ;
7. observer les logs ;
8. ajouter quelques tests ;
9. documenter le service ;
10. intégrer Helm seulement lorsque le comportement local est stable.

## Exemple de parcours complet

```text
Code minimal
    |
    v
Tests unitaires
    |
    v
Image Docker
    |
    v
Docker Compose
    |
    v
Tests d’intégration MQTT
    |
    v
Chart Helm
    |
    v
Minikube
    |
    v
Probes et métriques
    |
    v
CI
    |
    v
Documentation
```

## Éviter les intégrations prématurées

Il n’est pas nécessaire d’ajouter immédiatement un service expérimental :

- au chart Helm principal ;
- à Argo CD ;
- au monitoring complet ;
- à tous les workflows CI ;
- à un environnement de production.

Une expérimentation peut rester indépendante tant que :

- son objectif n’est pas stabilisé ;
- ses contrats changent fréquemment ;
- sa fiabilité n’est pas suffisante ;
- son déploiement n’est pas encore nécessaire.

!!! info "Airflow"

    Airflow pourra être expérimenté comme composant indépendant avant toute intégration au chart principal.

    Il ne doit pas être ajouté à l’application seulement parce qu’il est envisagé dans l’architecture future.

## Pages associées

- [Consommer la télémétrie](telemetry-consumer.md)
- [Contrats de messages](message-contracts.md)
- [Airflow](airflow.md)
- [Vue générale](../architecture/overview.md)
- [Docker Compose local](../getting-started/local-docker.md)
- [Dev Container et Minikube](../getting-started/devcontainer-minikube.md)
- [Commandes disponibles](../getting-started/commands.md)
