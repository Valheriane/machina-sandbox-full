# Monitoring

Machina Sandbox Full dispose d'une pile d'observabilité déployée dans le cluster
Minikube `machina`.

Elle permet de surveiller :

- l'état du cluster Kubernetes ;
- les pods applicatifs ;
- leur consommation CPU et mémoire ;
- les redémarrages ;
- l'état du nœud Minikube ;
- les journaux du broker, de Fleet API et du frontend.

L'observabilité est déployée dans le namespace :

```text
monitoring
```

---

## Architecture

La pile actuelle repose sur quatre composants principaux :

```text
Pods Machina
broker / fleet-api / front
        |
        +-----------------------------+
        |                             |
        v                             v
   métriques                       journaux
        |                             |
        v                             v
 Prometheus                        Grafana Alloy
        |                             |
        |                             v
        |                            Loki
        |                             |
        +--------------+--------------+
                       |
                       v
                    Grafana
                       |
                       v
              Machina Control Sandbox
```

### Prometheus

Prometheus collecte et conserve les métriques Kubernetes.

Il permet notamment d'observer :

- l'utilisation CPU ;
- l'utilisation mémoire ;
- l'état des pods ;
- les redémarrages ;
- l'état des Deployments ;
- l'état du nœud Minikube.

### Grafana

Grafana fournit l'interface de visualisation.

Il utilise actuellement deux sources de données principales :

```text
Prometheus
Loki
```

### Loki

Loki centralise les journaux Kubernetes.

Il fonctionne actuellement en mode monolithique avec un seul replica et un stockage
local adapté au bac à sable.

### Grafana Alloy

Grafana Alloy collecte les journaux des pods applicatifs dans le namespace :

```text
machina-sandbox
```

puis les transmet à Loki.

Le flux actuel est donc :

```text
stdout / stderr des pods
        |
        v
Grafana Alloy
        |
        v
Loki
        |
        v
Grafana
```

---

## Versions actuellement validées

Les versions utilisées dans le cluster `machina` sont actuellement :

| Composant            | Chart Helm                     | Version applicative |
| -------------------- | ------------------------------ | ------------------- |
| Prometheus + Grafana | `kube-prometheus-stack-88.1.5` | `v0.93.0`           |
| Loki                 | `loki-18.7.6`                  | `3.7.6`             |
| Alloy                | `alloy-1.11.1`                 | `v1.18.1`           |

Ces versions sont volontairement fixées dans la configuration afin de rendre
l'installation reproductible.

---

## Fichiers de configuration

Les configurations de l'observabilité sont versionnées dans :

```text
Application/k8s/monitoring/
```

Les principaux fichiers sont :

```text
Application/k8s/monitoring/prometheus-values.yaml
Application/k8s/monitoring/loki-values.yaml
Application/k8s/monitoring/alloy-values.yaml
Application/k8s/monitoring/dashboards/machina-control-sandbox.json
```

Le dashboard Machina est donc conservé dans Git et ne dépend pas uniquement de la
base interne de Grafana.

---

## Vérifier le monitoring

Depuis le **Dev Container**, commencer par vérifier la connexion au cluster :

```bash
make k8s-connect
```

Puis afficher les releases Helm :

```bash
helm --kube-context machina list -n monitoring
```

Les trois releases attendues sont :

```text
monitoring
loki
alloy
```

Afficher ensuite les pods :

```bash
kubectl --context machina get pods -n monitoring
```

Les composants principaux doivent être en état :

```text
Running
```

Une vérification plus synthétique de Prometheus et Grafana peut être réalisée avec :

```bash
make devcont-monitoring-check
```

L'état général peut être affiché avec :

```bash
make devcont-monitoring-status
```

---

## Accéder à Grafana

Grafana n'est pas exposé directement à l'extérieur du cluster.

L'accès se fait avec un port-forward local :

```bash
kubectl --context machina \
  --namespace monitoring \
  port-forward svc/monitoring-grafana 3000:80
```

L'interface devient alors disponible sur :

```text
http://localhost:3000
```

Le terminal reste occupé tant que le port-forward est actif.

Pour l'arrêter :

```text
Ctrl+C
```

Cette opération n'arrête pas Grafana dans Kubernetes.

!!! warning "Identifiants Grafana"
Ne jamais copier le mot de passe administrateur Grafana dans Git, la
documentation, une issue ou des logs partagés.

---

## Dashboard Machina Control Sandbox

Un dashboard spécifique au projet est disponible :

```text
Machina Control Sandbox
```

Il contient actuellement des panneaux permettant notamment d'observer :

- le nombre de pods Running ;
- les pods non prêts ;
- les redémarrages cumulés ;
- les redémarrages sur les dernières 24 heures ;
- l'état du nœud Kubernetes ;
- le CPU consommé par pod ;
- la mémoire consommée par pod ;
- l'utilisation CPU globale du nœud ;
- l'utilisation mémoire globale ;
- les répliques désirées et disponibles ;
- les logs applicatifs provenant de Loki.

Le fichier source est versionné dans :

```text
Application/k8s/monitoring/dashboards/machina-control-sandbox.json
```

---

## Provisionnement automatique du dashboard

Le dashboard ne doit pas être recréé manuellement pour chaque nouveau développeur.

Le chart Grafana installé avec `kube-prometheus-stack` possède un sidecar nommé :

```text
grafana-sc-dashboard
```

Ce sidecar surveille les ConfigMaps possédant le label :

```text
grafana_dashboard=1
```

Le fonctionnement est le suivant :

```text
machina-control-sandbox.json
        |
        v
ConfigMap Kubernetes
        |
        | grafana_dashboard=1
        v
grafana-sc-dashboard
        |
        v
/tmp/dashboards/
        |
        v
Grafana
```

La cible Make suivante provisionne le dashboard :

```bash
make devcont-dashboard-install
```

Cette commande utilise :

```text
Application/scripts/observability/install-dashboard.sh
```

Le script est idempotent.

Si le ConfigMap n'existe pas, il est créé.

S'il existe déjà avec le même contenu, Kubernetes retourne :

```text
unchanged
```

Si le fichier JSON a changé, le ConfigMap est mis à jour et le sidecar demande à
Grafana de recharger les dashboards.

---

## Vérifier le dashboard provisionné

Afficher le ConfigMap :

```bash
kubectl --context machina \
  get configmap machina-control-sandbox-dashboard \
  --namespace monitoring \
  --show-labels
```

Le label suivant doit être présent :

```text
grafana_dashboard=1
```

Vérifier que le fichier a été chargé par le sidecar :

```bash
kubectl --context machina \
  exec \
  --namespace monitoring \
  deployment/monitoring-grafana \
  --container grafana \
  -- \
  ls -lh /tmp/dashboards
```

Le fichier suivant doit apparaître :

```text
machina-control-sandbox.json
```

Le sidecar peut également être contrôlé avec :

```bash
kubectl --context machina \
  logs \
  --namespace monitoring \
  deployment/monitoring-grafana \
  --container grafana-sc-dashboard
```

Lors d'un chargement réussi, une réponse similaire à celle-ci est attendue :

```text
Dashboards config reloaded
```

---

## Vérifier la synchronisation avec Git

Le fichier du dépôt et celui stocké dans Kubernetes peuvent être comparés avec
SHA-256.

Fichier Git :

```bash
sha256sum \
  Application/k8s/monitoring/dashboards/machina-control-sandbox.json
```

ConfigMap Kubernetes :

```bash
kubectl --context machina \
  get configmap machina-control-sandbox-dashboard \
  --namespace monitoring \
  -o jsonpath='{.data.machina-control-sandbox\.json}' \
  | sha256sum
```

Lorsque les deux empreintes sont identiques, le dashboard présent dans Kubernetes
correspond exactement au fichier versionné.

---

## Modifier le dashboard

Le dashboard peut être modifié dans Grafana afin de tester de nouveaux panneaux.

Une fois la modification validée :

1. exporter le dashboard au format JSON V2 ;
2. remplacer :

```text
Application/k8s/monitoring/dashboards/machina-control-sandbox.json
```

3. vérifier le JSON :

```bash
python -m json.tool \
  Application/k8s/monitoring/dashboards/machina-control-sandbox.json \
  >/dev/null
```

4. reprovisionner :

```bash
make devcont-dashboard-install
```

5. contrôler les modifications avec Git :

```bash
git diff -- \
  Application/k8s/monitoring/dashboards/machina-control-sandbox.json
```

Le fichier versionné doit être considéré comme la source de vérité du dashboard.

---

## Persistance

Tous les composants ne possèdent pas le même niveau de persistance.

### Dashboard Grafana

La persistance interne de Grafana n'est actuellement pas nécessaire pour conserver le
dashboard Machina, car celui-ci est versionné dans Git et reprovisionné à partir d'un
ConfigMap.

Un remplacement du pod Grafana ne doit donc pas nécessiter de recréer manuellement
le dashboard.

### Loki

Loki dispose actuellement d'un volume persistant local :

```text
storage-loki-0
```

La capacité configurée est :

```text
10Gi
```

Ce stockage reste adapté au bac à sable local.

Il ne constitue pas une architecture de stockage destinée à un environnement de
production.

### Prometheus

L'historique Prometheus est actuellement volontairement limité et adapté à un
environnement local de développement.

---

## Sécurité

La pile d'observabilité est destinée au cluster Minikube local.

Les interfaces ne doivent pas être exposées directement sur un réseau public.

Grafana est accessible par port-forward.

Loki utilise actuellement une configuration simplifiée adaptée au laboratoire.

Les mots de passe, tokens et Secrets Kubernetes ne doivent jamais être :

- versionnés ;
- copiés dans la documentation ;
- ajoutés dans des captures d'écran ;
- publiés dans une issue ;
- partagés dans des logs.

---

## Installation reproductible

L'automatisation complète de l'installation est en cours de construction.

La cible déjà disponible pour le dashboard est :

```bash
make devcont-dashboard-install
```

Les prochaines cibles doivent permettre d'automatiser séparément :

```text
Prometheus + Grafana
Loki
Alloy
dashboard Machina
vérifications
```

L'objectif final est de disposer d'une commande unique :

```text
make devcont-observability-bootstrap
```

Cette cible n'est pas encore considérée comme disponible tant que toutes ses étapes
n'ont pas été testées individuellement.

!!! note "Principe"
Le Dev Container prépare les outils nécessaires, mais il ne doit pas déployer
silencieusement toute l'observabilité lors de sa création.

```
L'installation Kubernetes reste une opération explicite.
```

---

## État actuellement validé

Au 19 août 2026, le cluster local `machina` a été vérifié avec :

```text
Prometheus   : opérationnel
Grafana      : opérationnel
Loki         : opérationnel
Alloy        : opérationnel
métriques    : visibles dans Grafana
logs         : transmis vers Loki
dashboard    : provisionné depuis Kubernetes
ConfigMap    : synchronisé avec le JSON versionné
```

La chaîne complète actuellement validée est :

```text
Pods Machina
   |
   +---- métriques ----> Prometheus -----+
   |                                     |
   +---- logs ---------> Alloy -> Loki ---+
                                         |
                                         v
                                      Grafana
                                         |
                                         v
                              Machina Control Sandbox
```
