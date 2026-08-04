
# Machina Sandbox Full

Projet bac à sable pour expérimenter une application distribuée autour de **MachinaControl** avec :

- un **broker MQTT** (Mosquitto)
- une **API backend**
- un **frontend**
- un déploiement **Docker / Kubernetes / Helm**
- une supervision avec **Prometheus, Grafana et Loki**
- une logique **GitOps** via **Argo CD**

---

## 1. Objectif du projet

Ce dépôt sert de terrain d’expérimentation pour :

- déployer une application conteneurisée
- l’orchestrer avec Kubernetes
- la packager avec Helm
- superviser métriques et logs
- structurer un déploiement GitOps

---

## 2. Architecture générale

Le projet contient plusieurs briques :

- **Broker MQTT** : communication machine-to-machine
- **Backend** : logique applicative / API
- **Frontend** : interface utilisateur
- **Kubernetes** : orchestration des services
- **Helm** : packaging de l’application
- **Prometheus** : collecte des métriques
- **Grafana** : visualisation
- **Loki** : centralisation des logs
- **Argo CD** : synchronisation GitOps

---

## 3. Structure du projet

```text
machina-sandbox-full/
├── .github/
│   └── workflows/
├── agents/
├── broker/
├── fleet-api/
├── front/
├── k8s/
│   ├── argocd/
│   ├── backend-deploy.yaml
│   ├── broker-deploy.yaml
│   ├── front-deploy.yaml
│   ├── loki-values.yaml
│   └── namespace.yaml
├── machina-sandbox/
│   ├── charts/
│   ├── templates/
│   ├── Chart.yaml
│   └── values.yaml
├── scripts/
│   ├── restart-project.sh
│   ├── check-project.sh
│   ├── open-grafana.sh
│   └── check-monitoring.sh
├── docker-compose.yml
└── README.md
````

---

## 4. Pré-requis

Avant de lancer le projet, vérifier que les outils suivants sont installés :

* **Docker**
* **kubectl**
* **Helm**
* **Minikube**
* **Git**

Optionnel selon usage :

* **Node.js** pour lancer le front hors Docker
* **Python 3.11+** pour certains scripts/outils

---

## 5. Lancement local avec Docker

### Vérifier la configuration

```bash
docker compose config
```

### Lancer toute l’application

```bash
docker compose up --build
```

### Lancer uniquement broker + backend

```bash
docker compose up --build broker backend
```

### Arrêter

```bash
docker compose down
```

### Arrêter et supprimer les volumes

```bash
docker compose down -v
```

### Rebuild complet

```bash
docker compose up --build --force-recreate
```

---

## 6. Déploiement Kubernetes / Minikube

### Démarrer Minikube

```bash
minikube start
```

### Vérifier le cluster

```bash
kubectl cluster-info
kubectl get nodes
kubectl get ns
```

### Réappliquer les manifests Kubernetes

```bash
kubectl apply -f k8s/
```

Ou fichier par fichier :

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/broker-deploy.yaml
kubectl apply -f k8s/backend-deploy.yaml
kubectl apply -f k8s/front-deploy.yaml
```

### Vérifier les pods applicatifs

```bash
kubectl get pods -n machina-sandbox
kubectl get svc -n machina-sandbox
```

---

## 7. Déploiement Helm

Le chart Helm principal de l’application se trouve dans :

```text
machina-sandbox/
```

### Installer le chart en test

```bash
helm install machina-test ./machina-sandbox -n machina-helm-test
```

### Vérifier les releases Helm

```bash
helm list -A
```

---

## 8. Supervision

La supervision a été mise en place dans le namespace :

```text
monitoring
```

Elle inclut :

* **Prometheus**
* **Grafana**
* **Loki**

### Ajouter les repositories Helm

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### Créer le namespace monitoring

```bash
kubectl create namespace monitoring
```

### Installer Prometheus + Grafana

```bash
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring
```

### Installer Loki

```bash
helm install loki grafana/loki -n monitoring -f k8s/loki-values.yaml
```

### Vérifier les composants monitoring

```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
helm list -n monitoring
```

---

## 9. Accéder à Grafana

### Lancer le port-forward

```bash
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
```

### URL d’accès

```text
http://localhost:3000
```

### Récupérer le mot de passe admin

```bash
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

---

## 10. Sources de données Grafana

### Prometheus

URL utilisée :

```text
http://monitoring-kube-prometheus-prometheus.monitoring:9090
```

### Loki

URL utilisée :

```text
http://loki-gateway.monitoring.svc.cluster.local/


http://loki.monitoring.svc.cluster.local:3100
```

---

## 11. Dashboard Grafana

Le projet inclut :

* les dashboards Kubernetes provisionnés automatiquement par `kube-prometheus-stack`
* un dashboard personnalisé de supervision Machina

Exemples d’indicateurs affichés :

* usage CPU du nœud
* usage mémoire du nœud
* pods Machina actifs
* nombre total de pods
* pods par namespace
* pods problématiques
* mémoire par namespace

---

## 12. Scripts utilitaires

Pour simplifier la reprise du projet, plusieurs scripts Bash ont été ajoutés.

### 12.1 Relancer l’environnement

```bash
./scripts/restart-project.sh
```

Ce script :

* vérifie la présence de `minikube`, `kubectl`, `helm`, `docker`
* démarre Minikube
* vérifie le cluster Kubernetes
* affiche les nœuds
* affiche les namespaces
* affiche les releases Helm
* affiche les pods et services monitoring
* affiche les pods applicatifs
* affiche le mot de passe Grafana

---

### 12.2 Audit complet du projet

```bash
./scripts/check-project.sh
```

Ce script vérifie :

* outils installés
* état de Minikube
* état du cluster
* namespaces attendus
* releases Helm
* stack monitoring
* application métier
* Argo CD
* Docker

Il fournit aussi un résumé final avec :

* OK
* WARN
* ERROR

---

### 12.3 Vérification rapide de la supervision

```bash
./scripts/check-monitoring.sh
```

Ce script affiche :

* pods monitoring
* services monitoring
* releases Helm monitoring
* pods Loki
* pods Prometheus
* pods Grafana

---

### 12.4 Ouvrir Grafana

```bash
./scripts/open-grafana.sh
```

---

## 13. Logs utiles

### Broker

```bash
docker logs -f mqtt-broker
```

### Backend

```bash
docker logs -f backend
```

### Front

```bash
docker logs -f front
```

### Broker MQTT dans Kubernetes

```bash
kubectl logs -f -l app=broker -n machina-sandbox
```

### Backend dans Kubernetes

```bash
kubectl logs -f -l app=fleet-api -n machina-sandbox
```

### Front dans Kubernetes

```bash
kubectl logs -f -l app=front -n machina-sandbox
```

---

## 14. Debug Kubernetes

### Voir tous les pods

```bash
kubectl get pods -A
```

### Voir les services

```bash
kubectl get svc -A
```

### Décrire un pod

```bash
kubectl describe pod <pod-name> -n <namespace>
```

### Voir les événements

```bash
kubectl get events -n <namespace> --sort-by=.metadata.creationTimestamp
```

### Redémarrer un déploiement

```bash
kubectl rollout restart deployment <deployment-name> -n <namespace>
```

---

## 15. Debug MQTT

Entrer dans le conteneur broker :

```bash
docker exec -it mqtt-broker sh
```

Écouter tous les topics :

```bash
mosquitto_sub -h localhost -p 1883 -t '#' -v
```

Publier un message de test :

```bash
mosquitto_pub -h localhost -p 1883 -t test -m "hello"
```

---

## 16. GitOps

Le projet utilise Argo CD pour expérimenter une approche GitOps.

### Principe

Le dépôt Git devient la source de vérité :

* manifests Kubernetes
* configuration Argo CD
* chart Helm
* fichiers de valeurs
* scripts d’exploitation

### Intérêt du GitOps dans le projet

* centraliser la configuration
* tracer les modifications
* simplifier les redéploiements
* rendre l’infrastructure reproductible
* faciliter l’audit et la maintenance

---

## 17. Points d’attention

* En environnement **Minikube**, certains pods peuvent parfois rester en `Pending` sans bloquer totalement le projet.
* La supervision fonctionne tant que le cluster Minikube existe.
* Quitter la conversation ou fermer l’éditeur ne supprime pas Grafana.
* En revanche, un `minikube delete` supprime le cluster local et donc les ressources déployées.

---

## 18. Commandes utiles — mémo rapide

### Relance projet

```bash
./scripts/restart-project.sh
```

### Audit projet

```bash
./scripts/check-project.sh
```

### Ouvrir Grafana

```bash
./scripts/open-grafana.sh
```

### Vérifier la supervision

```bash
./scripts/check-monitoring.sh
```

### Démarrer Minikube

```bash
minikube start
```

### Voir les pods monitoring

```bash
kubectl get pods -n monitoring
```

### Voir les services monitoring

```bash
kubectl get svc -n monitoring
```

---

## 19. État actuel du projet

À ce stade, le projet permet déjà de démontrer :

* conteneurisation avec Docker
* orchestration avec Kubernetes
* packaging avec Helm
* supervision métrique avec Prometheus + Grafana
* intégration de Loki pour les logs
* scripts de relance et d’audit
* début d’approche GitOps avec Argo CD

---

## 20. Pistes d’amélioration

* structurer davantage les fichiers de supervision dans `k8s/monitoring/`
* ajouter `prometheus-values.yaml` et `grafana-values.yaml`
* affiner la collecte de logs avec Promtail
* ajouter un `Makefile`
* améliorer la partie GitOps de la supervision
* enrichir le dashboard Grafana avec des indicateurs plus orientés Green IT

---

## 21. Auteur

Projet réalisé dans le cadre d’un bac à sable personnel autour de MachinaControl, pour expérimenter :

* Kubernetes
* Helm
* observabilité
* GitOps
* supervision d’une application distribuée

```

