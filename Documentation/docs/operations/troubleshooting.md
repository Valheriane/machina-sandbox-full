# Dépannage

Cette page rassemble les procédures de diagnostic courantes pour **Machina Sandbox Full**.

Le projet utilise plusieurs couches :

```text
machine hôte Linux
        |
        v
Docker
        |
        v
Minikube
        |
        v
Kubernetes
        |
        v
broker + fleet-api + front
```

Le développement est réalisé depuis un Dev Container, mais le cluster Minikube s’exécute sur la machine hôte.

Un problème peut donc provenir :

- de la machine hôte ;
- de Docker ;
- de Minikube ;
- de la connexion du Dev Container ;
- de Kubernetes ;
- de Helm ;
- d’un service applicatif ;
- du navigateur ;
- d’un script historique.

## Principe de diagnostic

Avant de modifier ou de réinstaller quoi que ce soit :

1. identifier le terminal utilisé ;
2. vérifier l’état de Minikube ;
3. vérifier la connexion Kubernetes ;
4. vérifier la release Helm ;
5. vérifier les pods ;
6. consulter les événements ;
7. consulter les logs ;
8. seulement ensuite envisager une correction.

!!! danger "Ne pas supprimer pour diagnostiquer"

    Ne pas commencer un diagnostic avec :

    ```bash
    minikube delete
    ```

    ou :

    ```bash
    kubectl delete namespace
    ```

    ou :

    ```bash
    helm uninstall
    ```

    Ces commandes peuvent supprimer des ressources, des données ou tout le cluster local.

---

# Identifier le terminal utilisé

## Terminal de l’hôte

Le terminal de l’hôte utilise le chemin réel du dépôt, par exemple :

```text
/media/.../machina-sandbox-full
```

Il permet notamment de :

- démarrer Minikube ;
- arrêter Minikube ;
- vérifier le profil ;
- piloter le moteur Docker de la machine.

## Terminal du Dev Container

Le terminal du Dev Container utilise généralement :

```text
/workspaces/machina-sandbox-full
```

Il permet notamment de :

- développer ;
- lancer les tests ;
- utiliser Docker Compose ;
- utiliser `kubectl` ;
- utiliser Helm ;
- déployer l’application ;
- construire la documentation.

## Vérification rapide

```bash
pwd
```

Puis :

```bash
test -f /.dockerenv \
  && echo "Conteneur Docker" \
  || echo "Machine hôte"
```

---

# Une commande demande de quitter le Dev Container

## Symptôme

Une commande affiche :

```text
Cette commande pilote le Minikube de la machine hôte.
Quitte le Dev Container puis relance-la depuis le terminal local.
```

## Cause

La cible Make dépend de :

```text
ensure-local
```

Cette protection bloque volontairement certaines commandes dans le Dev Container.

Elle concerne notamment certaines commandes historiques comme :

```text
check-monitoring
check-prometheus
check-loki
check-argocd
open-grafana
open-argocd
```

## Solution

Exécuter la commande depuis un terminal de la machine hôte.

Pour les opérations Kubernetes ordinaires depuis le Dev Container, utiliser plutôt :

```bash
make k8s-connect
make k8s-status
```

!!! note "Exécution directe d’un script"

    Exécuter directement un script avec `bash` peut contourner `ensure-local`.

    Cette méthode ne doit pas être utilisée sans avoir lu le script et compris son contexte.

---

# Minikube est-il démarré ?

## Vérification depuis l’hôte

```bash
minikube status -p machina
```

Résultat attendu — ne pas copier :

```text
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

## Avec le Makefile

```bash
make host-status
```

## Démarrer un profil existant

```bash
make host-start
```

ou :

```bash
minikube start -p machina
```

## Minikube est partiellement arrêté

Lorsque certaines lignes sont en état `Stopped`, relancer :

```bash
minikube start -p machina
```

Puis vérifier :

```bash
minikube status -p machina
```

---

# Le mauvais profil Minikube est utilisé

## Symptômes possibles

- le cluster semble vide ;
- le contexte Kubernetes est inattendu ;
- les pods connus ont disparu ;
- `minikube status` affiche un autre profil ;
- une commande utilise le profil par défaut `minikube`.

## Afficher les profils

```bash
minikube profile list
```

Le profil attendu pour ce projet est :

```text
machina
```

## Afficher le contexte Kubernetes

```bash
kubectl config current-context
```

Le contexte attendu est :

```text
machina
```

## Corriger le contexte sur l’hôte

```bash
minikube update-context -p machina
```

Dans le Dev Container, relancer ensuite :

```bash
make k8s-connect
```

---

# `make host-status` ou `make host-start` échoue dans `machina-host`

## Exemple d’erreur

```text
tools/host/machina-host: line 22: .: filename argument required
.: usage: . filename [arguments]
```

## Signification

La commande Bash :

```text
.
```

est un alias de :

```text
source
```

Elle doit recevoir un nom de fichier.

Cette erreur peut indiquer :

- un point isolé dans le script ;
- une variable contenant un chemin vide ;
- une erreur de syntaxe ;
- un caractère invisible.

## Inspecter les lignes concernées

```bash
nl -ba tools/host/machina-host \
  | sed -n '15,30p'
```

Afficher les caractères invisibles :

```bash
sed -n '15,30l' tools/host/machina-host
```

Vérifier la syntaxe :

```bash
bash -n tools/host/machina-host
```

Afficher les modifications locales :

```bash
git diff -- tools/host/machina-host
```

Ne pas remplacer tout le script sans comprendre la ligne fautive.

---

# Minikube fonctionne mais `kubectl` ne répond pas

## Symptômes possibles

```text
The connection to the server was refused
```

ou :

```text
Unable to connect to the server
```

ou un délai d’attente.

## Vérification depuis le Dev Container

```bash
make k8s-connect
```

Puis :

```bash
kubectl cluster-info
```

## Vérifier le contexte

```bash
kubectl config current-context
```

## Vérifier le serveur utilisé

```bash
kubectl config view \
  --minify \
  --output jsonpath='{.clusters[0].cluster.server}'

echo
```

L’adresse peut changer lorsque Minikube redémarre.

Elle ne doit pas être copiée comme une valeur permanente dans le dépôt.

## Vérifier le conteneur Minikube depuis l’hôte

```bash
docker ps \
  --filter name=machina
```

## Reconnexion

Depuis le Dev Container :

```bash
make k8s-connect
```

Le script reconnecte le Dev Container au réseau Docker de Minikube et actualise l’accès à l’API Kubernetes.

---

# `make k8s-connect` réussit mais aucun pod n’apparaît

## Vérifier tous les namespaces

```bash
kubectl get pods \
  --all-namespaces
```

## Cas 1 : seuls les pods `kube-system` sont présents

Cela signifie que Kubernetes fonctionne, mais que l’application n’est pas déployée.

Vérifier les releases :

```bash
helm list \
  --all-namespaces
```

## Cas 2 : la release `machina-sandbox` est absente

Pour une première installation depuis le Dev Container :

```bash
make devcont-bootstrap
```

## Cas 3 : la release existe mais les répliques sont à zéro

Afficher les Deployments :

```bash
kubectl get deployments \
  --namespace machina-sandbox
```

Relancer l’application :

```bash
make devcont-start
```

## Cas 4 : les pods sont dans un autre namespace

Afficher les namespaces :

```bash
kubectl get namespaces
```

Puis :

```bash
kubectl get pods \
  --all-namespaces
```

Le namespace principal attendu est :

```text
machina-sandbox
```

---

# Le namespace existe mais il est vide

## Exemple

```text
No resources found in monitoring namespace.
```

## Signification

Le namespace existe, mais aucun pod, Service ou autre ressource du type demandé n’y est installé.

Cela ne signifie pas que Kubernetes est en panne.

## Vérifier les ressources

```bash
kubectl get all \
  --namespace monitoring
```

Puis :

```bash
helm list \
  --namespace monitoring
```

## Cas actuel du monitoring

Le namespace :

```text
monitoring
```

peut exister sans contenir :

- Prometheus ;
- Grafana ;
- Loki ;
- collecteur de logs.

Les scripts de contrôle du monitoring ne réalisent pas leur installation.

## Ne pas confondre avec l’application

L’application principale se trouve dans :

```text
machina-sandbox
```

Vérification :

```bash
kubectl get pods \
  --namespace machina-sandbox
```

---

# Une release Helm est absente

## Afficher toutes les releases

```bash
helm list \
  --all-namespaces
```

## Afficher uniquement la release applicative

```bash
helm list \
  --namespace machina-sandbox
```

## Vérifier son état

```bash
helm status machina-sandbox \
  --namespace machina-sandbox
```

## Première installation

```bash
make devcont-bootstrap
```

## Mise à jour

```bash
make devcont-deploy
```

!!! warning "Avant un déploiement"

    Valider d’abord le chart :

    ```bash
    make validate-k8s
    ```

---

# La release existe mais aucun pod n’est prêt

## Vérifier les ressources

```bash
kubectl get deployments,pods,services \
  --namespace machina-sandbox
```

## Vérifier les rollouts

```bash
kubectl rollout status deployment/broker \
  --namespace machina-sandbox
```

```bash
kubectl rollout status deployment/fleet-api \
  --namespace machina-sandbox
```

```bash
kubectl rollout status deployment/front \
  --namespace machina-sandbox
```

## Examiner les événements

```bash
kubectl get events \
  --namespace machina-sandbox \
  --sort-by=.metadata.creationTimestamp
```

## Examiner un pod

```bash
kubectl describe pod \
  --namespace machina-sandbox \
  <nom-du-pod>
```

---

# Un pod est en `CrashLoopBackOff`

## Signification

Le conteneur démarre, s’arrête en erreur, puis Kubernetes tente de le redémarrer.

## Afficher les pods

```bash
kubectl get pods \
  --namespace machina-sandbox
```

## Afficher les logs actuels

```bash
kubectl logs \
  --namespace machina-sandbox \
  <nom-du-pod> \
  --tail=200
```

## Afficher les logs précédents

```bash
kubectl logs \
  --namespace machina-sandbox \
  <nom-du-pod> \
  --previous \
  --tail=200
```

## Examiner le pod

```bash
kubectl describe pod \
  --namespace machina-sandbox \
  <nom-du-pod>
```

## Causes possibles

- erreur de configuration ;
- variable d’environnement absente ;
- commande de démarrage invalide ;
- dépendance inaccessible ;
- port déjà utilisé dans le conteneur ;
- fichier attendu absent ;
- probe incorrecte ;
- permission insuffisante.

---

# Un pod est en `ImagePullBackOff`

## Cause probable dans ce projet

Les images locales sont utilisées avec une politique proche de :

```text
imagePullPolicy: Never
```

L’image doit donc déjà être présente dans le nœud Minikube.

## Vérifier les événements

```bash
kubectl describe pod \
  --namespace machina-sandbox \
  <nom-du-pod>
```

## Reconstruire les images

```bash
make devcont-build-images
```

## Charger les images dans Minikube

```bash
make devcont-load-images
```

## Redéployer

```bash
make devcont-deploy
```

## Vérifier les images dans Minikube

Depuis l’hôte :

```bash
minikube image ls \
  -p machina
```

Rechercher notamment :

```text
fleet-api:latest
front:latest
eclipse-mosquitto:2
```

---

# Un pod reste en `Pending`

## Examiner le pod

```bash
kubectl describe pod \
  --namespace machina-sandbox \
  <nom-du-pod>
```

## Vérifier les événements

```bash
kubectl get events \
  --namespace machina-sandbox \
  --sort-by=.metadata.creationTimestamp
```

## Causes possibles

- ressources CPU ou mémoire insuffisantes ;
- volume indisponible ;
- règle de planification impossible ;
- image en cours de téléchargement ;
- nœud non prêt.

## Vérifier le nœud

```bash
kubectl get nodes \
  --output wide
```

Puis :

```bash
kubectl describe node machina
```

---

# Fleet API est démarrée mais non prête

## Symptôme

Le pod est en cours d’exécution, mais la readiness probe échoue.

La route concernée est :

```text
/ready
```

## Cause fréquente

Fleet API considère qu’elle n’est pas prête lorsque la connexion MQTT n’est pas disponible.

## Vérifier Fleet API

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --tail=200
```

## Vérifier le broker

```bash
kubectl logs \
  deployment/broker \
  --namespace machina-sandbox \
  --tail=200
```

## Vérifier les Services

```bash
kubectl get services \
  --namespace machina-sandbox
```

## Vérifier les endpoints

```bash
kubectl get endpoints \
  --namespace machina-sandbox
```

## Vérifier la configuration du Deployment

```bash
kubectl get deployment fleet-api \
  --namespace machina-sandbox \
  --output yaml
```

Rechercher notamment :

```text
MQTT_HOST
MQTT_PORT
```

Le service attendu est généralement :

```text
broker
```

sur le port :

```text
1883
```

---

# Le broker MQTT ne démarre pas

## Afficher les logs

```bash
kubectl logs \
  deployment/broker \
  --namespace machina-sandbox \
  --tail=200
```

## Examiner le Deployment

```bash
kubectl describe deployment broker \
  --namespace machina-sandbox
```

## Examiner la configuration

```bash
kubectl get configmap \
  --namespace machina-sandbox
```

Puis afficher le ConfigMap concerné :

```bash
kubectl get configmap \
  <nom-du-configmap> \
  --namespace machina-sandbox \
  --output yaml
```

## Causes possibles

- syntaxe Mosquitto incorrecte ;
- port déclaré deux fois ;
- fichier de configuration absent ;
- problème de montage ;
- listener non disponible ;
- image absente ;
- probe TCP en échec.

## Valider le chart avant correction

```bash
make validate-k8s
```

---

# Le frontend ne s’ouvre pas dans Kubernetes

## Vérifier les pods et Services

```bash
kubectl get pods,services \
  --namespace machina-sandbox
```

## Afficher les URL calculées

```bash
make devcont-status
```

## Afficher l’adresse de Minikube

Depuis l’hôte :

```bash
minikube ip \
  -p machina
```

## Vérifier les logs Nginx

```bash
kubectl logs \
  deployment/front \
  --namespace machina-sandbox \
  --tail=200
```

## Tester le Service depuis le cluster

```bash
kubectl run curl-front-test \
  --rm \
  --interactive \
  --tty \
  --restart=Never \
  --image=curlimages/curl:8.7.1 \
  --namespace machina-sandbox \
  -- \
  curl -I http://front
```

## Le site s’ouvre mais les données ne chargent pas

Ouvrir les outils de développement du navigateur :

```text
F12 → Console
```

et :

```text
F12 → Réseau
```

Rechercher :

- une erreur CORS ;
- une URL API incorrecte ;
- une erreur WebSocket ;
- une réponse `404` ;
- une réponse `503` ;
- un contenu mixte HTTP/HTTPS.

## Vérifier la configuration runtime

Le frontend utilise un fichier de configuration runtime.

Vérifier sa présence dans le conteneur :

```bash
kubectl exec \
  deployment/front \
  --namespace machina-sandbox \
  -- \
  ls -l /usr/share/nginx/html
```

Puis :

```bash
kubectl exec \
  deployment/front \
  --namespace machina-sandbox \
  -- \
  sed -n '1,160p' /usr/share/nginx/html/config.js
```

Avant de partager cette sortie, vérifier qu’elle ne contient aucune information sensible.

---

# Le frontend ne communique pas avec Fleet API

## Vérifier Fleet API

```bash
kubectl get pods \
  --namespace machina-sandbox
```

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --tail=200
```

## Tester `/health`

Depuis le Dev Container, utiliser l’URL affichée par :

```bash
make devcont-status
```

Puis :

```bash
curl http://<adresse-api>/health
```

Résultat attendu — ne pas copier :

```json
{ "status": "ok", "mqtt_connected": true }
```

La valeur MQTT peut être `false` lorsque le broker n’est pas connecté.

## Tester `/ready`

```bash
curl http://<adresse-api>/ready
```

Une réponse `503` peut indiquer que MQTT n’est pas connecté.

## Vérifier CORS

Afficher la variable déployée :

```bash
kubectl get deployment fleet-api \
  --namespace machina-sandbox \
  --output yaml \
  | grep -A 3 -B 3 CORS
```

Le déploiement depuis le Dev Container calcule l’origine autorisée à partir de l’adresse actuelle de Minikube.

Un redémarrage ou une recréation du cluster peut modifier cette adresse.

Dans ce cas :

```bash
make devcont-deploy
```

---

# La connexion MQTT WebSocket échoue

## Vérifier le Service

```bash
kubectl get service broker \
  --namespace machina-sandbox \
  --output yaml
```

## Vérifier les ports du broker

```bash
kubectl get service broker \
  --namespace machina-sandbox
```

Le projet utilise notamment :

```text
1883  MQTT
9001  MQTT WebSocket
```

Les NodePorts sont affichés avec :

```bash
make devcont-status
```

## Vérifier les logs du broker

```bash
kubectl logs \
  deployment/broker \
  --namespace machina-sandbox \
  --tail=200
```

## Vérifier le port depuis le Dev Container

```bash
nc -vz \
  <adresse-minikube> \
  <nodeport-websocket>
```

L’adresse et le NodePort doivent être récupérés avec :

```bash
make devcont-status
```

## Causes possibles

- listener WebSocket absent ;
- mauvais port ;
- mauvaise adresse ;
- frontend utilisant la configuration Compose dans Kubernetes ;
- frontend utilisant la configuration Kubernetes dans Compose ;
- broker non prêt ;
- réseau bloqué ;
- page HTTPS tentant d’ouvrir un WebSocket non sécurisé.

---

# Docker Compose ne démarre pas

## Valider la configuration

```bash
make compose-config
```

## Démarrer

```bash
make compose-up
```

## Afficher l’état

```bash
make compose-status
```

## Consulter les logs

```bash
make compose-logs
```

## Causes possibles

- port déjà utilisé ;
- variable `.env` absente ou invalide ;
- image impossible à construire ;
- dépendance indisponible ;
- dossier monté inaccessible ;
- fichier Mosquitto invalide ;
- ancien conteneur portant le même nom.

---

# Un port Docker Compose est déjà utilisé

## Exemple d’erreur

```text
address already in use
```

ou :

```text
port is already allocated
```

## Vérifier les ports principaux

```bash
ss -ltnp \
  | grep -E ':(1883|9001|8000|8085|8086)\b'
```

## Vérifier les conteneurs

```bash
docker ps \
  --format 'table {{.Names}}\t{{.Ports}}'
```

## Vérifier l’environnement Compose

```bash
make compose-config
```

## Solutions possibles

- arrêter l’ancien environnement Compose ;
- modifier le port dans `Application/.env` ;
- arrêter le processus qui utilise déjà le port ;
- éviter de démarrer Compose et Kubernetes sur des ports locaux concurrents.

Arrêter Compose :

```bash
make compose-down
```

---

# Docker Compose fonctionne mais le frontend utilise les mauvais ports

## Cause possible

Le projet utilise deux mécanismes de configuration :

- variables de construction Vite ;
- fichier runtime `config.js`.

Docker Compose et Kubernetes n’utilisent pas nécessairement les mêmes ports.

## Vérifier la configuration générée

```bash
make compose-config
```

## Vérifier le fichier runtime du conteneur

```bash
docker compose \
  --project-directory Application \
  --file Application/docker-compose.yml \
  exec front \
  sed -n '1,160p' /usr/share/nginx/html/config.js
```

## Vérifier le navigateur

```text
F12 → Console
```

Puis :

```text
F12 → Réseau
```

Vérifier les URL réellement appelées.

## Après correction

Reconstruire le frontend :

```bash
make compose-up
```

---

# Un port-forward échoue

## Exemple

```text
services "monitoring-grafana" not found
```

## Cause

Le Service ciblé n’existe pas dans le namespace demandé.

La commande de port-forward n’installe pas l’application.

## Vérifier le Service

```bash
kubectl get services \
  --namespace monitoring
```

## Vérifier les releases

```bash
helm list \
  --namespace monitoring
```

Si la sortie est vide, Grafana n’est probablement pas installé.

## Port local déjà utilisé

Exemple :

```text
Unable to listen on port 3000
```

Vérifier :

```bash
ss -ltnp \
  | grep ':3000'
```

Utiliser un autre port lorsque le script le permet, ou arrêter le processus existant.

## Arrêter un port-forward

Dans le terminal concerné :

```text
Ctrl+C
```

---

# Les commandes de monitoring ne retournent rien

## Symptôme

```bash
helm list --namespace monitoring
```

ne retourne aucune release.

```bash
kubectl get pods --namespace monitoring
```

affiche :

```text
No resources found in monitoring namespace.
```

## Signification

Le monitoring n’est pas encore déployé dans le cluster actuel.

La présence des fichiers suivants ne suffit pas :

```text
Application/k8s/loki-values.yaml
Application/scripts/check-monitoring.sh
Application/scripts/open-grafana.sh
```

Ils ne réalisent pas à eux seuls l’installation.

## État à documenter

```text
Prometheus : absent
Grafana    : absent
Loki       : absent
Collecteur : absent
```

L’installation reproductible sera réalisée dans un chantier séparé.

---

# Argo CD ne répond pas

## Vérifier le namespace

```bash
kubectl get namespace argocd
```

## Vérifier les pods

```bash
kubectl get pods \
  --namespace argocd
```

## Vérifier le Service

```bash
kubectl get service argocd-server \
  --namespace argocd
```

## Vérifier les CRD

```bash
kubectl get crd applications.argoproj.io
```

## Aucun résultat

La présence de manifests dans Git ne signifie pas qu’Argo CD est installé.

Les fichiers suivants sont actuellement expérimentaux :

```text
Application/k8s/argocd/app-helm.yaml
Application/k8s/argocd/applicationset-machina.yaml
Application/app-test.yaml
```

Ils ne doivent pas être appliqués ensemble.

---

# Argo CD annule une modification manuelle

## Symptôme

Une modification faite avec `kubectl edit` disparaît après quelques secondes ou minutes.

## Cause possible

L’Application utilise :

```yaml
selfHeal: true
```

Argo CD rétablit alors l’état présent dans Git.

## Vérifier les Applications

```bash
kubectl get applications \
  --namespace argocd
```

## Vérifier une Application

```bash
kubectl get application \
  <nom-application> \
  --namespace argocd \
  --output yaml
```

## Correction recommandée

Modifier la source de vérité dans Git, puis synchroniser.

Ne pas lutter contre `selfHeal` en répétant les modifications manuelles.

---

# Une ressource Kubernetes disparaît avec Argo CD

## Cause possible

L’Application utilise :

```yaml
prune: true
```

Une ressource absente de Git peut être supprimée dans Kubernetes.

## Vérifier l’historique Git

```bash
git log \
  --oneline \
  -- \
  chemin/du/manifeste
```

## Vérifier les événements Argo CD

```bash
kubectl describe application \
  <nom-application> \
  --namespace argocd
```

## Précaution

Ne pas activer `prune` sur un chemin contenant :

- des manifests historiques ;
- plusieurs approches de déploiement ;
- des ressources partagées ;
- des volumes non audités.

---

# Helm et Argo CD semblent gérer les mêmes ressources

## Symptômes possibles

- changements annulés ;
- labels ou annotations qui changent ;
- ressources recréées ;
- statut Argo CD `OutOfSync` ;
- Helm affiche une release, mais Argo CD tente aussi de la gérer.

## Vérifier les releases

```bash
helm list \
  --all-namespaces
```

## Vérifier les Applications Argo CD

```bash
kubectl get applications \
  --namespace argocd
```

## Vérifier les annotations Helm

```bash
kubectl get deployment fleet-api \
  --namespace machina-sandbox \
  --output yaml \
  | grep -A 4 -B 4 'meta.helm.sh'
```

## Règle

Une ressource doit avoir une source de vérité principale.

Ne pas appliquer simultanément :

```text
Application/machina-sandbox/
Application/k8s/apps/
Application/app-test.yaml
Application/k8s/argocd/applicationset-machina.yaml
```

sans avoir défini leurs périmètres.

---

# `make validate-k8s` échoue

## Relancer la commande

```bash
make validate-k8s
```

La cible réalise plusieurs étapes :

```text
helm lint
helm template
kubeconform
```

## Erreur `helm lint`

Vérifier notamment :

```text
Chart.yaml
values.yaml
templates/
```

Exécuter directement :

```bash
helm lint Application/machina-sandbox
```

## Erreur de rendu

```bash
helm template \
  machina-sandbox \
  Application/machina-sandbox
```

Le message indique généralement le fichier et la ligne concernés.

## Inspecter le rendu généré

```bash
less /tmp/machina-rendered.yaml
```

Quitter avec :

```text
q
```

## Causes fréquentes

- indentation YAML incorrecte ;
- variable Helm absente ;
- guillemet manquant ;
- type invalide ;
- nom de champ Kubernetes incorrect ;
- ressource séparée par un mauvais `---`.

---

# `make devcont-deploy` échoue

## Première étape

Relancer les validations séparément :

```bash
make validate-k8s
```

## Vérifier la connexion

```bash
make k8s-connect
```

## Vérifier Docker

```bash
docker info
```

## Vérifier les images

```bash
docker image ls \
  | grep -E 'fleet-api|front|eclipse-mosquitto'
```

## Vérifier Helm

```bash
helm list \
  --namespace machina-sandbox
```

## Vérifier les événements

```bash
kubectl get events \
  --namespace machina-sandbox \
  --sort-by=.metadata.creationTimestamp
```

## Vérifier l’historique de release

```bash
helm history machina-sandbox \
  --namespace machina-sandbox
```

## Échec avec rollback automatique

La cible utilise une option de rollback en cas d’échec.

Après l’erreur, vérifier l’état réel :

```bash
helm status machina-sandbox \
  --namespace machina-sandbox
```

Puis :

```bash
kubectl get deployments,pods,services \
  --namespace machina-sandbox
```

---

# La documentation MkDocs ne se construit pas

## Validation

```bash
make docs-check
```

## Causes fréquentes

- page mentionnée dans `nav` mais absente ;
- lien interne incorrect ;
- indentation YAML incorrecte ;
- bloc de code non fermé ;
- fichier contenant des caractères invisibles ;
- dépendances MkDocs absentes.

## Installer les dépendances

```bash
make docs-install
```

## Vérifier le fichier MkDocs

```bash
sed -n '1,320p' Documentation/mkdocs.yml
```

## Vérifier les fichiers vides

```bash
find Documentation/docs \
  -type f \
  -empty \
  -print
```

## Vérifier les caractères problématiques

```bash
git diff --check
```

## Servir localement

```bash
make docs-serve
```

Puis ouvrir :

```text
http://localhost:8001
```

---

# Une commande Bash affiche une erreur de syntaxe

## Vérifier le script

```bash
bash -n chemin/du/script.sh
```

## Afficher les numéros de ligne

```bash
nl -ba chemin/du/script.sh \
  | sed -n '1,260p'
```

## Afficher les caractères invisibles

```bash
sed -n '1,260l' chemin/du/script.sh
```

## Causes fréquentes

- parenthèse manquante ;
- guillemet non fermé ;
- point isolé ;
- fin de ligne Windows ;
- variable vide utilisée avec `source` ;
- bloc `if` sans `fi` ;
- bloc `case` sans `esac`.

---

# Un script n’est pas exécutable

## Symptôme

```text
Permission denied
```

## Vérifier les droits

```bash
ls -l chemin/du/script.sh
```

## Corriger

```bash
chmod +x chemin/du/script.sh
```

Pour les scripts applicatifs :

```bash
make permissions
```

## Vérifier avec Git

```bash
git diff --summary
```

Git peut versionner le changement du bit exécutable.

---

# Le dépôt est monté sur une partition qui pose problème

## Symptômes possibles

- droits inattendus ;
- bit exécutable non conservé ;
- fichiers impossibles à modifier ;
- erreurs liées aux fins de ligne ;
- différences entre Windows et Linux.

## Vérifier le montage

```bash
mount \
  | grep "$(df --output=target . | tail -n 1)"
```

## Vérifier les droits

```bash
ls -ld .
ls -l tools/host/machina-host
```

## Vérifier le format de fichier

```bash
sed -n '1,20l' tools/host/machina-host
```

Une fin de ligne Windows peut apparaître sous la forme :

```text
\r$
```

## Convertir un script après vérification

```bash
sed -i 's/\r$//' chemin/du/script.sh
```

Ne pas appliquer cette commande à tout le dépôt sans inspection.

---

# Les données Fleet API ont disparu après un redéploiement Kubernetes

## Cause possible

Fleet API utilise SQLite.

Le déploiement Kubernetes actuel ne possède pas encore de stockage persistant confirmé pour cette base.

Lorsque le pod est remplacé, les données écrites uniquement dans son système de fichiers peuvent disparaître.

## Vérifier le pod

```bash
kubectl get pods \
  --namespace machina-sandbox
```

## Vérifier les volumes du Deployment

```bash
kubectl get deployment fleet-api \
  --namespace machina-sandbox \
  --output yaml
```

Rechercher :

```text
volumes
volumeMounts
persistentVolumeClaim
```

## Vérifier les PVC

```bash
kubectl get persistentvolumeclaims \
  --namespace machina-sandbox
```

Une sortie vide confirme qu’aucun PVC n’est présent dans ce namespace.

!!! warning "Pas de restauration automatique"

    Sans sauvegarde ou volume persistant, les données supprimées avec un ancien pod ne sont généralement pas récupérables.

---

# Les données Mosquitto diffèrent entre Compose et Kubernetes

## Docker Compose

La configuration Compose utilise un dossier lié au dépôt pour les données du broker.

## Kubernetes

Le chart actuel ne possède pas la même persistance confirmée.

## Conséquence

Le remplacement du pod Kubernetes peut perdre :

- la base de persistance Mosquitto ;
- les messages persistants ;
- certaines données de session.

## Vérifier les volumes

```bash
kubectl get deployment broker \
  --namespace machina-sandbox \
  --output yaml
```

Puis :

```bash
kubectl get persistentvolumeclaims \
  --namespace machina-sandbox
```

Ne pas considérer les environnements Compose et Kubernetes comme équivalents pour la persistance.

---

# Procédure de diagnostic générale

## Étape 1 — Hôte

```bash
minikube status -p machina
```

## Étape 2 — Connexion du Dev Container

```bash
make k8s-connect
```

## Étape 3 — Contexte

```bash
kubectl config current-context
```

## Étape 4 — Releases

```bash
helm list \
  --all-namespaces
```

## Étape 5 — Pods

```bash
kubectl get pods \
  --all-namespaces
```

## Étape 6 — Application

```bash
kubectl get deployments,pods,services \
  --namespace machina-sandbox
```

## Étape 7 — Événements

```bash
kubectl get events \
  --namespace machina-sandbox \
  --sort-by=.metadata.creationTimestamp
```

## Étape 8 — Logs

```bash
kubectl logs \
  deployment/fleet-api \
  --namespace machina-sandbox \
  --tail=200
```

Adapter le Deployment au service concerné.

---

# Rapport de diagnostic à partager

Lorsqu’une aide extérieure est nécessaire, partager de préférence :

```bash
kubectl config current-context
```

```bash
helm list \
  --all-namespaces
```

```bash
kubectl get pods \
  --all-namespaces
```

```bash
kubectl get deployments,pods,services \
  --namespace machina-sandbox
```

```bash
kubectl get events \
  --namespace machina-sandbox \
  --sort-by=.metadata.creationTimestamp
```

Puis les logs ciblés :

```bash
kubectl logs \
  deployment/<service> \
  --namespace machina-sandbox \
  --tail=200
```

## À masquer avant partage

Ne jamais publier :

- mots de passe ;
- tokens ;
- Secrets Kubernetes décodés ;
- contenu de `.env` ;
- clé `SHARED_SECRET` ;
- identifiants Grafana ;
- identifiants Argo CD ;
- kubeconfig complet ;
- clé privée ;
- contenu de `passwords.txt`.

---

# Commandes destructives à éviter

Ne pas lancer pendant un diagnostic ordinaire :

```bash
minikube delete -p machina
```

```bash
helm uninstall machina-sandbox \
  --namespace machina-sandbox
```

```bash
kubectl delete namespace machina-sandbox
```

```bash
kubectl delete namespace monitoring
```

```bash
kubectl delete namespace argocd
```

```bash
docker system prune --all
```

```bash
docker volume prune
```

Ces commandes nécessitent :

- une inspection préalable ;
- une compréhension des données ;
- une sauvegarde si nécessaire ;
- un accord explicite.

---

# État actuel connu

| Élément                          | État connu                             |
| -------------------------------- | -------------------------------------- |
| profil Minikube                  | `machina`                              |
| connexion Dev Container          | opérationnelle avec `make k8s-connect` |
| application Helm                 | release `machina-sandbox`              |
| namespace applicatif             | `machina-sandbox`                      |
| services applicatifs             | broker, fleet-api, front               |
| monitoring                       | à réinstaller                          |
| Loki                             | absent actuellement                    |
| Grafana                          | absent actuellement                    |
| Prometheus                       | absent actuellement                    |
| Argo CD                          | à auditer et réinstaller               |
| logs directs                     | disponibles                            |
| persistance Fleet API Kubernetes | non garantie                           |
| persistance broker Kubernetes    | non équivalente à Compose              |

## Pages associées

- [Consulter les logs](logging.md)
- [Scripts d’exploitation](scripts.md)
- [Monitoring](monitoring.md)
- [Dev Container et Minikube](../getting-started/devcontainer-minikube.md)
- [Docker Compose local](../getting-started/local-docker.md)
- [Commandes disponibles](../getting-started/commands.md)
- [Règles de déploiement](../gitops/deployment-rules.md)
