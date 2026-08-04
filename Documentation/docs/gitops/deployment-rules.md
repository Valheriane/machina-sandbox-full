# Règles de déploiement

Cette page décrit les règles de déploiement de **Machina Sandbox Full**.

Le projet possède actuellement plusieurs approches :

- Docker Compose pour le développement local ;
- Helm pour le déploiement Kubernetes dans Minikube ;
- des manifests Argo CD expérimentaux ;
- des manifests Kubernetes historiques.

Ces approches ne doivent pas gérer simultanément les mêmes ressources sans stratégie explicite.

## Objectifs

Les règles de déploiement doivent permettre de :

- savoir quelle source décrit chaque environnement ;
- éviter les conflits entre outils ;
- protéger les données ;
- vérifier les changements avant application ;
- distinguer développement local et Kubernetes ;
- préparer GitOps progressivement ;
- rendre les opérations reproductibles ;
- permettre un retour arrière compréhensible.

## État actuel

Le déploiement Kubernetes opérationnel utilise actuellement :

```text
Application/machina-sandbox/
```

Ce dossier contient le chart Helm principal.

La release déployée est :

```text
machina-sandbox
```

Le namespace utilisé est :

```text
machina-sandbox
```

Le déploiement est piloté depuis le Dev Container avec :

```bash
make devcont-deploy
```

## Ressources actuellement déployées

Le chart principal déploie :

```text
broker
fleet-api
front
```

Il génère notamment :

- un ConfigMap Mosquitto ;
- trois Deployments ;
- trois Services.

## Source de vérité actuelle

Pour le déploiement Kubernetes principal, la source de vérité actuelle est :

```text
Application/machina-sandbox/
```

Les manifests présents dans :

```text
Application/k8s/apps/
```

sont plus anciens ou expérimentaux.

Ils ne doivent pas être appliqués en parallèle du chart sans audit.

!!! danger "Une ressource, un seul gestionnaire"

    Une même ressource Kubernetes ne doit pas être gérée simultanément par :

    - Helm manuel ;
    - Argo CD avec Helm ;
    - Argo CD avec des manifests statiques ;
    - `kubectl apply` manuel.

    Cette concurrence peut provoquer des changements annulés, des suppressions ou des états difficiles à diagnostiquer.

## Environnements

| Environnement        | Outil principal          |
| -------------------- | ------------------------ |
| développement local  | Docker Compose           |
| Kubernetes local     | Helm dans Minikube       |
| observabilité future | releases Helm séparées   |
| GitOps futur         | Argo CD après validation |
| production réelle    | non définie              |

## Docker Compose

Docker Compose utilise :

```text
Application/docker-compose.yml
```

Il démarre actuellement :

```text
broker
fleet-api
front
```

Le déploiement Compose est indépendant de Kubernetes.

### Validation

Avant le démarrage :

```bash
make compose-config
```

### Démarrage

```bash
make compose-up
```

### État

```bash
make compose-status
```

### Arrêt

```bash
make compose-down
```

!!! note "Arrêt sans suppression des données liées"

    `make compose-down` arrête les conteneurs.

    Les données conservées dans les dossiers liés du dépôt ne sont pas automatiquement supprimées.

## Kubernetes avec Minikube

Le profil utilisé est :

```text
machina
```

Il fonctionne sur la machine hôte avec le pilote Docker.

Depuis l’hôte :

```bash
minikube status -p machina
```

Pour démarrer un profil existant :

```bash
minikube start -p machina
```

Le Dev Container se connecte ensuite avec :

```bash
make k8s-connect
```

## Validation du chart

Avant tout déploiement :

```bash
make validate-k8s
```

Cette cible exécute :

1. `helm lint` ;
2. `helm template` ;
3. kubeconform.

Le rendu est écrit dans :

```text
/tmp/machina-rendered.yaml
```

Il peut être inspecté avant application.

## Déploiement complet

La cible principale est :

```bash
make devcont-deploy
```

Elle effectue notamment :

- la connexion à Minikube ;
- la construction des images locales ;
- le chargement des images dans Minikube ;
- `helm upgrade --install` ;
- la configuration CORS du frontend ;
- l’attente des rollouts.

## Première installation

La cible :

```bash
make devcont-bootstrap
```

utilise le même déploiement complet.

Elle est destinée au premier déploiement depuis le Dev Container.

## Redémarrage sans reconstruction

Lorsqu’une release existe déjà :

```bash
make devcont-start
```

Cette commande redimensionne les Deployments à une réplique et attend leur disponibilité.

Elle ne reconstruit pas les images.

## Arrêt applicatif

```bash
make devcont-stop
```

Cette cible réduit les répliques applicatives à zéro.

Elle ne supprime pas :

- la release Helm ;
- le namespace ;
- le cluster ;
- les données externes au pod ;
- les images chargées dans Minikube.

## Contrôle

```bash
make devcont-check
make devcont-status
```

Ces commandes permettent de vérifier :

- la release ;
- les Deployments ;
- les pods ;
- les Services ;
- les NodePorts ;
- les routes principales.

## Images locales

Le chart utilise actuellement :

```text
fleet-api:latest
front:latest
```

avec :

```text
imagePullPolicy: Never
```

Les images doivent donc être disponibles dans Minikube.

La cible `devcont-deploy` les construit puis les charge dans le nœud.

!!! warning "Tag `latest`"

    Le tag `latest` est pratique pour le développement local.

    Il ne permet pas d’identifier précisément la version déployée.

    Un futur processus de release devra utiliser des tags d’image immuables.

## Modification du chart

Toute modification doit préciser :

- la ressource concernée ;
- la valeur par défaut ;
- le comportement en mise à jour ;
- l’effet sur une release existante ;
- les éventuelles données persistantes ;
- les nouvelles permissions ;
- les nouveaux ports ;
- les nouveaux Secrets ou ConfigMaps.

## Namespaces

Les namespaces actuellement utilisés ou envisagés sont :

| Namespace           | Rôle                              |
| ------------------- | --------------------------------- |
| `machina-sandbox`   | application principale            |
| `monitoring`        | observabilité future              |
| `argocd`            | Argo CD futur                     |
| `machina-helm-test` | ancien environnement de test Helm |

Le namespace :

```text
machina-helm-test
```

est utilisé dans un manifest Argo CD expérimental.

Il n’est pas le namespace du déploiement principal actuel.

## Manifests Argo CD existants

Trois approches sont présentes.

### Application Helm

```text
Application/k8s/argocd/app-helm.yaml
```

Configuration observée :

```text
Application : machina-helm
Branche     : dev
Chemin      : Application/machina-sandbox
Namespace   : machina-helm-test
```

Synchronisation :

```text
automated
prune
selfHeal
```

### ApplicationSet

```text
Application/k8s/argocd/applicationset-machina.yaml
```

Configuration observée :

```text
Branche     : main
Chemin      : Application/k8s/apps/*
Namespace   : machina-sandbox
```

Une Application Argo CD est générée par sous-dossier.

### Application de test

```text
Application/app-test.yaml
```

Configuration observée :

```text
Branche     : main
Chemin      : Application/k8s
Namespace   : machina-sandbox
```

## Risques des manifests actuels

Ces fichiers peuvent gérer des ressources proches ou identiques depuis plusieurs sources :

```text
Application/machina-sandbox/
Application/k8s/apps/
Application/k8s/
```

Ils utilisent également :

```text
dev
main
```

et plusieurs namespaces.

!!! danger "Ne pas les appliquer ensemble"

    L’application simultanée de ces manifests peut provoquer :

    - des ressources dupliquées ;
    - des conflits de propriétaires ;
    - des changements permanents annulés par `selfHeal` ;
    - des suppressions provoquées par `prune` ;
    - une divergence entre Helm et Git ;
    - des Services ou Deployments portant les mêmes noms.

## Argo CD non opérationnel actuellement

Les manifests Argo CD présents dans Git ne prouvent pas qu’Argo CD soit installé dans le cluster.

Avant toute application, vérifier :

```bash
kubectl get namespace argocd
kubectl get crd applications.argoproj.io
kubectl get pods --namespace argocd
```

L’installation reproductible d’Argo CD sera réalisée séparément.

## Activation future de GitOps

Avant d’activer Argo CD pour l’application principale, il faudra choisir :

1. une branche ;
2. un chemin Git ;
3. un namespace ;
4. une release ;
5. une source de vérité ;
6. une politique de synchronisation ;
7. une procédure de retour arrière.

## Stratégie GitOps recommandée

La solution la plus cohérente avec l’état actuel serait de commencer avec :

```text
Branche d’intégration : dev
Chemin Helm            : Application/machina-sandbox
Namespace              : machina-sandbox ou environnement de test distinct
```

Cependant, Argo CD ne doit pas prendre immédiatement le contrôle de la release actuelle sans test dans un namespace séparé.

## Environnement de test GitOps

Un premier test peut utiliser un namespace distinct, par exemple :

```text
machina-gitops-test
```

Ce choix permet de comparer :

- le déploiement Helm manuel ;
- le déploiement Argo CD ;
- les Services ;
- les ConfigMaps ;
- les probes ;
- les valeurs appliquées.

Une fois le comportement validé, une migration vers le namespace principal pourra être préparée.

## Déploiement manuel et Argo CD

Tant qu’Argo CD ne gère pas officiellement l’application :

```bash
make devcont-deploy
```

reste la commande de référence.

Après activation de GitOps, les modifications ordinaires devront passer par Git.

Éviter alors :

```bash
kubectl edit
kubectl apply
helm upgrade
```

sur les ressources gérées par Argo CD, sauf procédure explicitement documentée.

## `selfHeal`

La configuration actuelle contient :

```yaml
selfHeal: true
```

Cela signifie qu’Argo CD peut réappliquer l’état Git lorsqu’une ressource est modifiée manuellement.

Une correction réalisée directement avec `kubectl edit` peut donc être annulée.

## `prune`

La configuration actuelle contient :

```yaml
prune: true
```

Cela signifie qu’Argo CD peut supprimer une ressource qui n’existe plus dans la source Git.

!!! danger "Suppression automatique"

    Une suppression de fichier dans Git peut entraîner une suppression Kubernetes après synchronisation.

    `prune` ne doit être activé qu’après compréhension complète du périmètre géré.

## Synchronisation automatique

Une synchronisation automatique peut être utile dans un bac à sable.

Elle ne doit toutefois pas être activée immédiatement pour :

- une branche instable ;
- un chemin contenant des fichiers historiques ;
- plusieurs Applications concurrentes ;
- des ressources persistantes non protégées ;
- un namespace partagé avec un déploiement manuel.

## Secrets

Aucun Secret Kubernetes décodé ne doit être versionné.

Les manifests peuvent contenir des références :

```yaml
valueFrom:
  secretKeyRef:
    name: example-secret
    key: password
```

Mais la valeur réelle doit être fournie par une méthode séparée.

Les secrets concernés peuvent inclure :

```text
SHARED_SECRET
MQTT_PASSWORD
mot de passe Grafana
mot de passe Argo CD
identifiants de base de données
token de dépôt privé
```

## Secrets Argo CD

Si le dépôt Git devient privé, Argo CD aura besoin d’un accès authentifié.

Les identifiants du dépôt ne doivent pas être ajoutés dans :

```text
Application/k8s/argocd/
```

Ils doivent être enregistrés dans un Secret Argo CD ou un gestionnaire de secrets adapté.

## Persistance

Le chart principal ne possède actuellement aucune persistance Kubernetes pour Fleet API.

La base SQLite peut être perdue lors du remplacement du pod.

Avant d’utiliser GitOps avec des synchronisations automatiques, cette limite doit être comprise.

Une modification de Deployment peut provoquer la recréation du pod et donc la perte de données locales.

## Broker

La configuration Docker Compose active la persistance Mosquitto.

La configuration Helm actuelle ne définit pas la même persistance.

Un déploiement GitOps du broker ne doit donc pas être présenté comme équivalent au mode Compose pour la conservation des données.

## Monitoring

Prometheus, Grafana, Loki et Argo CD devront être installés avec des releases séparées.

Ils ne doivent pas être ajoutés directement comme dépendances obligatoires du chart :

```text
machina-sandbox
```

Une architecture prévue est :

```text
release machina-sandbox
release monitoring
release loki
release collecteur
release argocd
```

Les noms définitifs seront définis lors de leur installation reproductible.

## Ordre des changements

Pour un changement Kubernetes :

1. modifier le chart ;
2. exécuter `make validate-k8s` ;
3. inspecter le rendu ;
4. documenter les changements ;
5. tester dans Minikube ;
6. vérifier les rollouts ;
7. vérifier les logs ;
8. vérifier les Services ;
9. créer la pull request ;
10. activer GitOps seulement après validation.

## Vérification après déploiement

```bash
helm list --namespace machina-sandbox
```

```bash
kubectl get deployments,pods,services \
  --namespace machina-sandbox
```

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

## Logs après déploiement

```bash
kubectl logs \
  --namespace machina-sandbox \
  deployment/broker \
  --tail=100
```

```bash
kubectl logs \
  --namespace machina-sandbox \
  deployment/fleet-api \
  --tail=100
```

```bash
kubectl logs \
  --namespace machina-sandbox \
  deployment/front \
  --tail=100
```

## Diagnostic d’un rollout

```bash
kubectl describe deployment \
  --namespace machina-sandbox \
  fleet-api
```

```bash
kubectl describe pod \
  --namespace machina-sandbox \
  <nom-du-pod>
```

```bash
kubectl get events \
  --namespace machina-sandbox \
  --sort-by=.metadata.creationTimestamp
```

## Retour arrière Helm

Afficher l’historique :

```bash
helm history machina-sandbox \
  --namespace machina-sandbox
```

Un retour arrière manuel peut utiliser :

```bash
helm rollback machina-sandbox <revision> \
  --namespace machina-sandbox
```

!!! warning "Avant un rollback"

    Vérifier :

    - la révision ciblée ;
    - les changements de schéma ;
    - les ConfigMaps ;
    - les Secrets ;
    - les données persistantes ;
    - les images disponibles.

## Retour arrière GitOps

Avec Argo CD, la méthode privilégiée sera généralement :

1. corriger ou rétablir l’état dans Git ;
2. fusionner le correctif ;
3. laisser Argo CD synchroniser.

Un rollback réalisé uniquement dans le cluster peut être annulé par `selfHeal`.

## Suppressions interdites sans accord explicite

Ne pas exécuter automatiquement :

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

Ces opérations nécessitent une vérification préalable et un accord explicite.

## Déploiement depuis une branche de fonctionnalité

Une branche `feature/*` ne doit pas être suivie automatiquement par l’environnement GitOps principal.

Un test ponctuel peut être réalisé manuellement dans un namespace isolé.

Le déploiement automatique doit cibler une branche connue, comme :

```text
dev
```

ou :

```text
main
```

après validation de la stratégie.

## Pull request et déploiement

Le déploiement ne doit pas précéder systématiquement les validations.

Flux recommandé :

```text
branche de travail
      |
      v
validations locales
      |
      v
pull request
      |
      v
CI
      |
      v
fusion dans dev
      |
      v
déploiement d’intégration futur
```

Puis :

```text
dev validée
      |
      v
pull request vers main
      |
      v
release stable
```

## État actuel résumé

| Élément                   | État                      |
| ------------------------- | ------------------------- |
| Docker Compose            | opérationnel              |
| Helm manuel dans Minikube | opérationnel              |
| Chart principal           | source de vérité actuelle |
| Release `machina-sandbox` | déployée                  |
| Argo CD                   | à réinstaller et valider  |
| Application Helm Argo CD  | expérimentale             |
| ApplicationSet            | expérimental              |
| `app-test.yaml`           | expérimental              |
| GitOps automatisé         | non opérationnel          |
| Monitoring reproductible  | à mettre en place         |
| Production réelle         | non définie               |

## Décisions restantes

Les points suivants doivent encore être définis :

- branche suivie par Argo CD ;
- namespace de test GitOps ;
- migration de la release Helm existante ;
- activation ou non de `prune` ;
- activation ou non de `selfHeal` ;
- gestion des secrets ;
- persistance ;
- tags d’images ;
- stratégie de promotion ;
- environnement correspondant à `main` ;
- rôle de `prod` et `test`.

## Pages associées

- [Stratégie de branches](branching-strategy.md)
- [Règles de contribution](contribution-rules.md)
- [Versions et releases](release-process.md)
- [Environnements](../architecture/environments.md)
- [Dev Container et Minikube](../getting-started/devcontainer-minikube.md)
