# Consulter les logs

Les logs permettent de comprendre ce que font les services de **Machina Sandbox Full**, de repérer une erreur et de suivre le démarrage de l’application.

Le projet peut être exécuté dans deux environnements principaux :

- Docker Compose ;
- Kubernetes dans Minikube.

Les commandes de consultation ne sont pas les mêmes selon l’environnement utilisé.

## Objectifs

Cette page explique comment :

- consulter les logs de l’ensemble du projet ;
- suivre un service précis ;
- consulter les logs Docker Compose ;
- consulter les logs Kubernetes ;
- examiner les logs d’un conteneur redémarré ;
- rechercher les erreurs récentes ;
- compléter les logs avec les événements Kubernetes ;
- éviter d’exposer des secrets ;
- comprendre les limites actuelles de conservation.

## État actuel

| Élément                               | État                           |
| ------------------------------------- | ------------------------------ |
| logs Docker Compose                   | disponibles                    |
| logs Kubernetes                       | disponibles                    |
| logs du broker sur `stdout` dans Helm | configurés                     |
| logs centralisés dans Loki            | non opérationnels actuellement |
| recherche dans Grafana                | indisponible actuellement      |
| collecteur de logs Kubernetes         | à installer                    |
| conservation longue durée             | non configurée                 |

!!! info "Consultation directe"

    Tant que Loki et son collecteur ne sont pas installés, les logs doivent être consultés directement avec :

    ```text
    docker compose logs
    ```

    ou :

    ```text
    kubectl logs
    ```

## Identifier l’environnement actif

Avant de chercher une erreur, vérifier comment l’application a été démarrée.

### Docker Compose

```bash
make compose-status
```

### Kubernetes

```bash
make k8s-status
```

ou :

```bash
kubectl get pods \
  --namespace machina-sandbox
```

Les deux environnements peuvent exister en même temps.

Il faut donc vérifier que les logs consultés correspondent bien à l’instance utilisée.

## Services principaux

Les services actuels sont :

```text
broker
fleet-api
front
```

| Service     | Rôle                                |
| ----------- | ----------------------------------- |
| `broker`    | broker MQTT Mosquitto               |
| `fleet-api` | API FastAPI et gestion de la flotte |
| `front`     | frontend servi par Nginx            |

---

# Logs Docker Compose

## Vérifier les conteneurs

Depuis la racine du dépôt :

```bash
make compose-status
```

Cette commande affiche :

- les services actifs ;
- leur état ;
- leurs ports ;
- l’adresse de Fleet API ;
- l’adresse du frontend.

## Suivre tous les logs

```bash
make compose-logs
```

La cible exécute une commande équivalente à :

```bash
docker compose \
  --project-directory Application \
  --file Application/docker-compose.yml \
  logs \
  --follow \
  --tail=100
```

Elle affiche les 100 dernières lignes puis continue à suivre les nouvelles lignes.

Pour arrêter le suivi :

```text
Ctrl+C
```

Cette action arrête uniquement l’affichage des logs.

Elle n’arrête pas les conteneurs.

## Afficher les logs sans les suivre

```bash
docker compose \
  --project-directory Application \
  --file Application/docker-compose.yml \
  logs \
  --tail=100
```

La commande se termine après l’affichage.

## Suivre un service précis

### Broker MQTT

```bash
docker compose \
  --project-directory Application \
  --file Application/docker-compose.yml \
  logs \
  --follow \
  --tail=100 \
  broker
```

### Fleet API

```bash
docker compose \
  --project-directory Application \
  --file Application/docker-compose.yml \
  logs \
  --follow \
  --tail=100 \
  fleet-api
```

### Frontend

```bash
docker compose \
  --project-directory Application \
  --file Application/docker-compose.yml \
  logs \
  --follow \
  --tail=100 \
  front
```

## Suivre plusieurs services

```bash
docker compose \
  --project-directory Application \
  --file Application/docker-compose.yml \
  logs \
  --follow \
  --tail=100 \
  broker \
  fleet-api
```

Cette commande est utile pour suivre simultanément :

```text
Fleet API → broker MQTT
```

## Afficher les horodatages

```bash
docker compose \
  --project-directory Application \
  --file Application/docker-compose.yml \
  logs \
  --timestamps \
  --tail=100
```

Les horodatages permettent de comparer les événements entre plusieurs services.

## Afficher uniquement les logs récents

```bash
docker compose \
  --project-directory Application \
  --file Application/docker-compose.yml \
  logs \
  --since=10m
```

Exemples possibles :

```text
5m
10m
1h
```

## Rechercher un mot

Exemple avec le mot `error` :

```bash
docker compose \
  --project-directory Application \
  --file Application/docker-compose.yml \
  logs \
  --tail=500 \
  | grep -i error
```

Pour rechercher plusieurs termes :

```bash
docker compose \
  --project-directory Application \
  --file Application/docker-compose.yml \
  logs \
  --tail=500 \
  | grep -Ei 'error|warning|failed|exception'
```

!!! warning "Filtrage incomplet"

    Une erreur peut être écrite avec un terme différent ou apparaître sur plusieurs lignes.

    En cas de doute, relire également les logs sans `grep`.

## Redémarrer puis suivre les logs

```bash
make compose-restart
make compose-logs
```

Cette procédure permet d’observer le démarrage des services après un redémarrage.

Elle ne reconstruit pas nécessairement les images.

## Reconstruire puis suivre les logs

```bash
make compose-up
make compose-logs
```

`make compose-up` construit les images avant de démarrer les services.

---

# Logs Kubernetes

## Vérifier la connexion au cluster

Depuis le Dev Container :

```bash
make k8s-connect
```

Puis :

```bash
kubectl config current-context
```

Le contexte attendu est :

```text
machina
```

## Vérifier les pods

```bash
kubectl get pods \
  --namespace machina-sandbox
```

Avant de lire les logs, vérifier :

- le nom du pod ;
- son état ;
- son nombre de redémarrages ;
- la colonne `READY`.

## Consulter les logs par Deployment

L’utilisation du nom du Deployment évite de recopier le nom dynamique du pod.

### Broker MQTT

```bash
kubectl logs \
  deployment/broker \
  --namespace machina-sandbox \
  --tail=100
```

### Fleet API

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --tail=100
```

### Frontend

```bash
kubectl logs \
  deployment/front \
  --namespace machina-sandbox \
  --tail=100
```

## Suivre les logs

Ajouter l’option :

```text
--follow
```

Exemple pour Fleet API :

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --follow \
  --tail=100
```

Pour arrêter le suivi :

```text
Ctrl+C
```

Cela n’arrête pas le pod.

## Afficher les horodatages

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --timestamps \
  --tail=100
```

## Afficher les logs récents

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --since=10m
```

## Afficher un nombre précis de lignes

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --tail=500
```

## Consulter directement un pod

Lister les pods :

```bash
kubectl get pods \
  --namespace machina-sandbox
```

Puis :

```bash
kubectl logs \
  --namespace machina-sandbox \
  <nom-du-pod> \
  --tail=100
```

Remplacer :

```text
<nom-du-pod>
```

par le nom réellement affiché.

## Consulter les logs avant un redémarrage

Lorsqu’un conteneur a redémarré, Kubernetes peut conserver les logs de son exécution précédente.

```bash
kubectl logs \
  --namespace machina-sandbox \
  <nom-du-pod> \
  --previous \
  --tail=200
```

Cette commande est particulièrement utile lorsque la colonne `RESTARTS` est supérieure à zéro.

!!! note "Limite de `--previous`"

    `--previous` concerne l’instance précédente du conteneur dans le même pod.

    Elle ne permet pas de retrouver indéfiniment les logs de pods supprimés.

## Suivre un redémarrage

Dans un premier terminal :

```bash
kubectl get pods \
  --namespace machina-sandbox \
  --watch
```

Dans un second terminal :

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --follow \
  --tail=100
```

Pour quitter chaque suivi :

```text
Ctrl+C
```

---

# Comprendre les logs par service

## Broker MQTT

Le broker utilise Mosquitto.

La configuration locale actuelle active les niveaux :

```text
error
warning
notice
```

Dans le chart Helm, la destination suivante est explicitement configurée :

```text
stdout
```

Les logs du broker peuvent notamment aider à vérifier :

- le démarrage de Mosquitto ;
- l’ouverture des ports MQTT ;
- l’ouverture du port WebSocket ;
- les connexions et déconnexions ;
- les erreurs de configuration ;
- les erreurs de persistance ;
- les problèmes de protocole.

### Docker Compose

```bash
docker compose \
  --project-directory Application \
  --file Application/docker-compose.yml \
  logs \
  --follow \
  --tail=100 \
  broker
```

### Kubernetes

```bash
kubectl logs \
  deployment/broker \
  --namespace machina-sandbox \
  --follow \
  --tail=100
```

!!! warning "Volume de logs"

    Augmenter fortement le niveau de détail de Mosquitto peut produire beaucoup de logs, notamment avec une télémétrie fréquente.

    Toute modification de niveau doit être testée avant d’être conservée.

## Fleet API

Fleet API utilise FastAPI et Uvicorn.

Ses logs peuvent aider à vérifier :

- le démarrage de l’API ;
- la connexion au broker MQTT ;
- les requêtes HTTP ;
- les erreurs de validation ;
- les erreurs lors de l’envoi de commandes ;
- les arrêts ou redémarrages du processus.

### Docker Compose

```bash
docker compose \
  --project-directory Application \
  --file Application/docker-compose.yml \
  logs \
  --follow \
  --tail=100 \
  fleet-api
```

### Kubernetes

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --follow \
  --tail=100
```

Fleet API possède deux routes de santé :

```text
/health
/ready
```

`/ready` peut retourner une erreur lorsque la connexion MQTT n’est pas disponible.

Dans ce cas, consulter ensemble :

```text
fleet-api
broker
```

## Frontend

Le frontend React est construit avec Vite puis servi par Nginx dans son conteneur.

Les logs du conteneur peuvent aider à observer :

- le démarrage de Nginx ;
- les requêtes HTTP ;
- les fichiers introuvables ;
- certaines erreurs de serveur ;
- les arrêts du conteneur.

### Docker Compose

```bash
docker compose \
  --project-directory Application \
  --file Application/docker-compose.yml \
  logs \
  --follow \
  --tail=100 \
  front
```

### Kubernetes

```bash
kubectl logs \
  deployment/front \
  --namespace machina-sandbox \
  --follow \
  --tail=100
```

!!! note "Console du navigateur"

    Les erreurs JavaScript, MQTT ou Axios exécutées dans le navigateur peuvent ne pas apparaître dans les logs Nginx.

    Elles doivent aussi être recherchées dans les outils de développement du navigateur :

    ```text
    F12 → Console
    ```

    et :

    ```text
    F12 → Réseau
    ```

---

# Logs et événements Kubernetes

Les logs décrivent ce que le processus écrit.

Les événements Kubernetes décrivent ce que Kubernetes tente de faire autour du pod.

Les deux sources sont complémentaires.

## Afficher les événements

```bash
kubectl get events \
  --namespace machina-sandbox \
  --sort-by=.metadata.creationTimestamp
```

Cette commande permet de repérer notamment :

- une image absente ;
- un échec de probe ;
- un problème de montage ;
- un redémarrage ;
- un échec de planification ;
- une erreur de création du conteneur.

## Examiner un pod

```bash
kubectl describe pod \
  --namespace machina-sandbox \
  <nom-du-pod>
```

La partie située en bas de la sortie contient les événements associés.

## Examiner un Deployment

```bash
kubectl describe deployment \
  --namespace machina-sandbox \
  fleet-api
```

## Examiner tous les composants principaux

```bash
kubectl get deployments,pods,services \
  --namespace machina-sandbox
```

---

# Procédure de diagnostic rapide

## Docker Compose

```bash
make compose-status
make compose-logs
```

## Kubernetes

```bash
make k8s-connect
kubectl get pods --namespace machina-sandbox
kubectl get events --namespace machina-sandbox --sort-by=.metadata.creationTimestamp
```

Puis consulter le service concerné :

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --tail=200
```

## Pod en redémarrage

```bash
kubectl get pods \
  --namespace machina-sandbox
```

```bash
kubectl logs \
  --namespace machina-sandbox \
  <nom-du-pod> \
  --previous \
  --tail=200
```

```bash
kubectl describe pod \
  --namespace machina-sandbox \
  <nom-du-pod>
```

---

# Filtrer sans perdre le contexte

## Rechercher les erreurs

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --tail=500 \
  | grep -Ei 'error|warning|failed|exception'
```

## Rechercher MQTT

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --tail=500 \
  | grep -i mqtt
```

## Conserver quelques lignes autour d’un résultat

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --tail=500 \
  | grep -Ei -C 3 'error|exception'
```

!!! tip "Commencer sans filtre"

    Commencer par lire les dernières lignes sans filtre.

    Utiliser ensuite `grep` lorsque le volume devient trop important.

---

# Enregistrer temporairement une sortie

Une sortie peut être enregistrée localement pour faciliter son analyse.

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --tail=500 \
  > /tmp/fleet-api.log
```

Puis :

```bash
less /tmp/fleet-api.log
```

Pour quitter `less` :

```text
q
```

!!! warning "Ne pas versionner les exports de logs"

    Les fichiers de logs peuvent contenir :

    - des adresses ;
    - des identifiants techniques ;
    - des payloads ;
    - des erreurs détaillées ;
    - des informations sensibles.

    Ils ne doivent pas être ajoutés automatiquement à Git.

---

# Sécurité

## Ne pas afficher de secret

Les services ne doivent jamais écrire dans leurs logs :

- un mot de passe ;
- un token ;
- une clé privée ;
- un secret partagé ;
- le contenu complet d’un Secret Kubernetes ;
- une chaîne de connexion sensible.

Exemples concernés :

```text
SHARED_SECRET
MQTT_PASSWORD
mot de passe Grafana
mot de passe Argo CD
token GitHub
```

## Relire avant de partager

Avant de copier des logs dans une issue, une pull request ou une conversation :

1. rechercher les secrets ;
2. masquer les valeurs sensibles ;
3. conserver le message d’erreur utile ;
4. éviter de publier inutilement tout l’environnement.

## Afficher les variables d’un pod

Éviter d’utiliser une commande qui afficherait toutes les variables d’environnement sans vérification.

Certaines variables peuvent provenir de Secrets Kubernetes.

---

# Conservation et limites

## Docker Compose

La disponibilité des logs dépend du moteur Docker et de sa configuration.

Les logs peuvent disparaître après :

- la suppression d’un conteneur ;
- une rotation ;
- un nettoyage Docker ;
- la recréation complète de l’environnement.

## Kubernetes

`kubectl logs` lit les logs associés aux conteneurs présents sur le nœud.

Les logs peuvent devenir indisponibles après :

- la suppression d’un pod ;
- la recréation du cluster ;
- une rotation ;
- un nettoyage du nœud ;
- le remplacement de plusieurs générations de conteneurs.

## Absence actuelle de centralisation

Le namespace `monitoring` ne contient actuellement ni Loki ni collecteur de logs opérationnel.

Les logs ne sont donc pas encore :

- centralisés ;
- indexés ;
- conservés selon une politique définie ;
- interrogeables dans Grafana ;
- corrélés automatiquement entre services.

!!! warning "Scripts historiques"

    La présence de fichiers comme :

    ```text
    Application/scripts/check-loki.sh
    ```

    ou :

    ```text
    Application/k8s/loki-values.yaml
    ```

    ne signifie pas que Loki est installé.

    Ces fichiers préparent ou vérifient un environnement qui doit encore être remis en place.

---

# Évolution prévue avec Loki

Une future installation doit permettre le flux suivant :

```text
pods Kubernetes
       |
       v
collecteur de logs
       |
       v
Loki
       |
       v
Grafana Explore
```

La future documentation devra expliquer :

- le collecteur retenu ;
- les labels disponibles ;
- les namespaces collectés ;
- la durée de conservation ;
- les requêtes LogQL ;
- la recherche par service ;
- la recherche par pod ;
- la recherche par niveau ;
- la corrélation entre logs et métriques.

Cette partie sera ajoutée après l’installation reproductible de Loki et du collecteur.

---

# Commandes essentielles

## Docker Compose

```bash
make compose-status
make compose-logs
```

## Kubernetes

```bash
make k8s-connect
kubectl get pods --namespace machina-sandbox
```

## Fleet API

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --follow \
  --tail=100
```

## Broker

```bash
kubectl logs \
  deployment/broker \
  --namespace machina-sandbox \
  --follow \
  --tail=100
```

## Frontend

```bash
kubectl logs \
  deployment/front \
  --namespace machina-sandbox \
  --follow \
  --tail=100
```

## Événements

```bash
kubectl get events \
  --namespace machina-sandbox \
  --sort-by=.metadata.creationTimestamp
```

## Conteneur précédent

```bash
kubectl logs \
  --namespace machina-sandbox \
  <nom-du-pod> \
  --previous \
  --tail=200
```

## Pages associées

- [Monitoring](monitoring.md)
- [Scripts d’exploitation](scripts.md)
- [Dépannage](troubleshooting.md)
- [Docker Compose local](../getting-started/local-docker.md)
- [Dev Container et Minikube](../getting-started/devcontainer-minikube.md)
- [Broker MQTT](../services/broker-mqtt.md)
- [Fleet API](../services/fleet-api.md)
- [Frontend](../services/frontend.md)
