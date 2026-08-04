# Règles de contribution

Cette page décrit les règles recommandées pour contribuer à **Machina Sandbox Full**.

Le projet est un bac à sable technique en évolution. Les contributions doivent donc faciliter à la fois :

- l’expérimentation ;
- l’apprentissage ;
- la compréhension du dépôt ;
- la reproductibilité ;
- la stabilité des environnements existants.

## Objectifs

Les règles de contribution cherchent à éviter :

- les modifications difficiles à relire ;
- les secrets ajoutés accidentellement à Git ;
- les changements non testés ;
- les différences non documentées entre Docker Compose et Kubernetes ;
- les conflits entre Helm et Argo CD ;
- la suppression involontaire de ressources ;
- les fichiers générés enregistrés dans le dépôt ;
- les branches contenant plusieurs chantiers sans rapport.

## État actuel du dépôt

Le dépôt ne contient actuellement aucun fichier :

```text
CONTRIBUTING.md
CODEOWNERS
```

Les règles de cette page servent donc de référence documentaire interne.

Elles pourront être reprises plus tard dans un fichier `CONTRIBUTING.md` placé à la racine du dépôt.

## Principe général

Une contribution doit répondre à une question simple :

```text
Quel problème cette modification résout-elle ?
```

Avant de modifier le projet, il faut pouvoir expliquer :

- l’objectif ;
- le périmètre ;
- les fichiers concernés ;
- les risques ;
- les validations nécessaires ;
- les effets éventuels sur les autres environnements.

## Vérifier l’état du dépôt

Avant toute modification :

```bash
git status --short
```

Cette commande permet de vérifier :

- la branche active ;
- les fichiers modifiés ;
- les fichiers non suivis ;
- l’existence éventuelle d’un travail précédent non enregistré.

Pour afficher la branche courante :

```bash
git branch --show-current
```

## Choisir une branche adaptée

Une contribution est normalement réalisée dans une branche dédiée.

Exemples :

```text
feature/telemetry-consumer
feature/monitoring-bootstrap
fix/frontend-runtime-config
docs/operations
```

Le projet utilise actuellement principalement :

```text
feature/*
```

La branche de départ recommandée est :

```text
dev
```

Exemple :

```bash
git switch dev
git pull --ff-only
git switch -c feature/nom-du-chantier
```

Les règles détaillées sont présentées dans :

[Stratégie de branches](branching-strategy.md)

## Une contribution, un objectif principal

Une branche doit rester centrée sur un chantier identifiable.

Exemple cohérent :

```text
Ajouter un consommateur MQTT de télémétrie.
```

Cette branche peut contenir :

- le code du service ;
- ses tests ;
- son Dockerfile ;
- son intégration Compose ;
- sa documentation.

Exemple trop large :

```text
Modifier le frontend, installer Loki, changer la base de données,
réécrire la CI et ajouter Argo CD.
```

Les modifications sans lien direct doivent être séparées.

## Lire avant de modifier

Avant de modifier un fichier important, inspecter son contenu.

Exemples :

```bash
sed -n '1,260p' Makefile
```

```bash
sed -n '1,320p' Application/docker-compose.yml
```

```bash
sed -n '1,360p' Application/machina-sandbox/values.yaml
```

Cette règle est particulièrement importante pour :

- le Makefile ;
- Docker Compose ;
- le chart Helm ;
- les scripts ;
- les workflows CI ;
- les manifests Argo CD ;
- les fichiers de configuration ;
- les secrets et leurs références.

## Ne pas supprimer sans vérifier

Avant de supprimer un fichier ou une ressource :

1. rechercher ses références ;
2. vérifier son historique Git ;
3. identifier l’environnement qui l’utilise ;
4. vérifier s’il contient des données ;
5. déterminer s’il s’agit d’un fichier historique ou encore actif.

Exemple de recherche :

```bash
grep -RIn "nom-du-fichier" . \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=.venv
```

!!! danger "Ressources Kubernetes"

    Ne pas supprimer un namespace, une release Helm, un PersistentVolumeClaim ou le cluster Minikube sans accord explicite et sans inspection préalable.

## Style des commits

Le projet utilise progressivement une convention de type :

```text
type(scope): description
```

Exemples observés ou recommandés :

```text
feat(devcontainer): add simplified Minikube workflows
fix(host): mark helper as executable
docs(gitops): document contribution rules
ci(front): validate production build
```

## Types de commits

| Type       | Utilisation                                      |
| ---------- | ------------------------------------------------ |
| `feat`     | nouvelle fonctionnalité                          |
| `fix`      | correction                                       |
| `docs`     | documentation                                    |
| `test`     | ajout ou correction de tests                     |
| `refactor` | réorganisation sans changement fonctionnel voulu |
| `ci`       | intégration continue                             |
| `build`    | construction, dépendances ou images              |
| `chore`    | maintenance                                      |
| `style`    | format sans changement fonctionnel               |

## Portée du commit

La portée peut indiquer le composant concerné :

```text
fleet-api
front
broker
helm
compose
devcontainer
monitoring
argocd
docs
host
```

Exemples :

```text
fix(fleet-api): return command publication result
docs(front): document runtime configuration
feat(helm): add telemetry consumer deployment
```

## Commits compréhensibles

Un commit doit représenter une unité logique.

Éviter de mélanger dans un même commit :

- une correction fonctionnelle ;
- une réorganisation de fichiers sans rapport ;
- une modification du monitoring ;
- des fichiers générés ;
- des changements de format massifs ;
- des secrets.

Avant de créer un commit :

```bash
git diff
git diff --check
```

Pour vérifier uniquement les fichiers préparés :

```bash
git diff --cached
```

## Langue

Le code et les noms techniques peuvent rester en anglais.

La documentation principale est rédigée en français.

Les messages de commit peuvent progressivement être harmonisés en anglais ou en français, mais doivent surtout rester :

- explicites ;
- courts ;
- cohérents ;
- compréhensibles sans ouvrir immédiatement le diff.

## Secrets

Aucun secret réel ne doit être ajouté au dépôt.

Cela comprend notamment :

```text
SHARED_SECRET
MQTT_PASSWORD
DATABASE_PASSWORD
token GitHub
mot de passe Grafana
mot de passe Argo CD
kubeconfig
clé privée
certificat privé
```

## Fichiers sensibles

Avant un commit, vérifier particulièrement :

```text
.env
*.pem
*.key
*.crt
*.kubeconfig
passwords.txt
```

Le fichier Mosquitto :

```text
Application/broker/passwords.txt
```

ne doit jamais être affiché ou documenté avec son contenu.

## Valeurs de développement

Une valeur comme :

```text
dev-secret-change-me
```

peut servir de valeur de démonstration locale.

Elle ne doit pas être présentée comme une gestion sécurisée des secrets.

Un secret de démonstration doit être clairement identifié et ne jamais être réutilisé dans un environnement exposé.

## Variables GitHub Actions

Le workflow CI utilise actuellement :

```text
secrets.SHARED_SECRET
```

Un contributeur ne doit pas remplacer cette référence par une valeur inscrite directement dans :

```text
.github/workflows/ci.yml
```

## Fichiers générés

Les fichiers générés ne doivent généralement pas être versionnés.

Exemples :

```text
Documentation/site/
Application/front/dist/
__pycache__/
.pytest_cache/
*.pyc
*.db
```

Le fichier :

```text
Application/broker/mosquitto.db
```

est généré par Mosquitto et doit rester ignoré.

## Dépendances

Toute nouvelle dépendance doit être justifiée.

Questions à vérifier :

- est-elle réellement nécessaire ?
- est-elle maintenue ?
- possède-t-elle une licence compatible ?
- peut-elle être remplacée par la bibliothèque standard ?
- augmente-t-elle fortement la taille de l’image ?
- doit-elle être utilisée en production ou seulement en développement ?
- sa version doit-elle être verrouillée ?

## Dépendances Python

Chaque service Python doit posséder ses propres dépendances.

Exemples :

```text
Application/fleet-api/requirements.txt
Application/agents/drone/requirements.txt
```

Un nouveau service ne doit pas réutiliser directement :

```text
Application/fleet-api/.venv/
```

## Dépendances frontend

Le frontend utilise :

```text
package.json
package-lock.json
```

L’installation reproductible doit utiliser :

```bash
npm ci
```

Le fichier `package-lock.json` doit être mis à jour et versionné lorsqu’une dépendance change.

## Ajouter un service

Lorsqu’une contribution ajoute un nouveau service, elle doit vérifier au minimum :

- son dossier applicatif ;
- ses dépendances ;
- son Dockerfile ;
- ses variables d’environnement ;
- ses tests ;
- ses logs ;
- Docker Compose si nécessaire ;
- Helm si nécessaire ;
- la documentation ;
- la CI.

La procédure détaillée est décrite dans :

[Ajouter un service](../integrations/add-a-service.md)

## Contrats MQTT

Toute modification d’un topic ou d’un payload MQTT peut affecter :

- Fleet API ;
- le simulateur intégré ;
- l’agent autonome ;
- le frontend ;
- les futurs consommateurs ;
- les tests ;
- la documentation.

Avant de modifier un contrat :

1. rechercher tous ses usages ;
2. identifier les consommateurs ;
3. prévoir une compatibilité ou une migration ;
4. mettre à jour les exemples ;
5. mettre à jour la documentation.

Référence :

[Contrats de messages](../integrations/message-contracts.md)

## Docker Compose

Toute modification de :

```text
Application/docker-compose.yml
```

doit être validée avec :

```bash
make compose-config
```

Cette validation vérifie la structure et les variables résolues.

Lorsque le service peut être lancé localement :

```bash
make compose-up
make compose-status
```

Puis consulter les logs :

```bash
make compose-logs
```

Arrêt :

```bash
make compose-down
```

## Chart Helm

Toute modification de :

```text
Application/machina-sandbox/
```

doit être validée avec :

```bash
make validate-k8s
```

Cette cible réalise notamment :

- `helm lint` ;
- le rendu des manifests ;
- la validation kubeconform.

Le rendu peut être inspecté dans :

```text
/tmp/machina-rendered.yaml
```

## Kubernetes local

Le déploiement actuel depuis le Dev Container utilise :

```bash
make devcont-deploy
```

Cette commande :

- construit les images ;
- les charge dans Minikube ;
- applique la release Helm ;
- attend le déploiement des composants.

Elle ne doit être exécutée qu’après validation du chart.

## Argo CD

Les manifests Argo CD existants sont expérimentaux.

Ne pas appliquer automatiquement :

```text
Application/k8s/argocd/app-helm.yaml
Application/k8s/argocd/applicationset-machina.yaml
Application/app-test.yaml
```

avant d’avoir vérifié :

- la branche suivie ;
- le chemin Git ;
- le namespace de destination ;
- la source de vérité ;
- le risque de conflit avec Helm ;
- les options `prune` et `selfHeal`.

## Documentation

Une contribution qui change le comportement du projet doit mettre à jour la documentation correspondante.

Exemples :

| Modification           | Pages à vérifier                               |
| ---------------------- | ---------------------------------------------- |
| nouveau port           | `architecture/networking.md`                   |
| nouveau flux           | `architecture/data-flow.md`                    |
| nouveau service        | `services/` et `integrations/add-a-service.md` |
| nouveau topic          | `integrations/message-contracts.md`            |
| nouvelle commande Make | `getting-started/commands.md`                  |
| nouvelle probe         | page du service et exploitation                |
| nouveau déploiement    | `gitops/deployment-rules.md`                   |

## Validation MkDocs

Après modification de la documentation :

```bash
make docs-check
```

La génération stricte doit réussir.

Puis :

```bash
git diff --check
```

## Tests Fleet API

Les tests actuels utilisent `pytest`.

Depuis la racine :

```bash
Application/fleet-api/.venv/bin/python \
  -m pytest \
  Application/fleet-api/tests
```

Le workflow CI exécute également les tests backend avec Python 3.11.

## Validation du frontend

Depuis :

```text
Application/front/
```

utiliser :

```bash
npm run lint
npm run build
```

Le workflow CI exécute actuellement :

```text
npm ci
npm run build
```

Le lint n’est pas encore confirmé comme étape obligatoire de la CI.

## CI actuelle

Le workflow :

```text
.github/workflows/ci.yml
```

est exécuté lors :

- d’un push sur `dev` ;
- d’un push sur `main` ;
- d’une pull request.

Il contient actuellement deux jobs actifs :

```text
backend-tests
front-build
```

Le smoke test Docker Compose est commenté.

!!! warning "CI partielle"

    Une CI réussie ne garantit pas encore que :

    - Docker Compose fonctionne ;
    - le chart Helm est valide ;
    - MkDocs construit correctement le site ;
    - les manifests Argo CD sont sûrs ;
    - le monitoring fonctionne.

    Les validations locales restent nécessaires.

## Vérifications selon le changement

### Documentation uniquement

```bash
make docs-check
git diff --check
```

### Backend

```bash
Application/fleet-api/.venv/bin/python \
  -m pytest \
  Application/fleet-api/tests

git diff --check
```

### Frontend

```bash
cd Application/front
npm run lint
npm run build
```

### Docker Compose

```bash
make compose-config
```

### Kubernetes

```bash
make validate-k8s
```

### Modification transversale

```bash
make docs-check
make compose-config
make validate-k8s
git diff --check
```

Adapter la liste aux fichiers réellement modifiés.

## Pull request

Une contribution importante doit être présentée dans une pull request.

La cible habituelle d’une branche de fonctionnalité est :

```text
dev
```

La promotion de l’intégration stable se fait ensuite de :

```text
dev
```

vers :

```text
main
```

## Description recommandée

Une pull request devrait indiquer :

```text
Objectif
Modifications
Tests réalisés
Impacts
Limites connues
Documentation mise à jour
Suite éventuelle
```

Exemple :

```markdown
## Objectif

Ajouter la documentation du parcours Minikube.

## Modifications

- ajout des pages GitOps ;
- mise à jour de la navigation MkDocs ;
- clarification du déploiement Helm manuel.

## Validations

- `make docs-check`
- `git diff --check`

## Limites

Argo CD n’est pas encore installé dans le cluster actuel.
```

## Relecture du diff

Avant de demander une fusion :

```bash
git status --short
git diff --stat
git diff
```

Pour comparer la branche avec `dev` :

```bash
git fetch origin
git diff origin/dev...HEAD
```

## Résolution des conflits

Un conflit doit être compris avant d’être résolu.

Ne pas choisir automatiquement une version complète avec :

```text
ours
theirs
```

sans vérifier les modifications des deux branches.

Après résolution :

```bash
git status
git diff --check
```

Puis relancer les validations concernées.

## Changements de configuration

Lorsqu’une valeur par défaut change, documenter :

- l’ancienne valeur ;
- la nouvelle valeur ;
- l’environnement concerné ;
- le mécanisme de surcharge ;
- l’effet sur les installations existantes.

Exemples :

```text
port
topic MQTT
namespace
nom de release
variable d’environnement
NodePort
```

## Compatibilité

Une contribution doit éviter de casser silencieusement :

- les fichiers `.env` existants ;
- les scripts ;
- les commandes Make ;
- Docker Compose ;
- la release Helm ;
- les données SQLite ;
- les contrats MQTT ;
- les URL du frontend.

Lorsqu’une rupture est nécessaire, elle doit être clairement annoncée.

## Observabilité

Un nouveau service doit au minimum :

- écrire ses logs sur `stdout` ou `stderr` ;
- ne pas afficher de secret ;
- signaler ses erreurs ;
- gérer son arrêt proprement ;
- documenter son contrôle de santé.

Les métriques et la collecte centralisée pourront être ajoutées progressivement.

## Licence et code externe

Ne pas copier directement un code externe sans vérifier :

- sa licence ;
- sa source ;
- les obligations d’attribution ;
- sa compatibilité avec le projet.

Les extraits inspirés d’une documentation doivent être adaptés et compris.

## Contribution expérimentale

Une expérimentation incomplète peut être conservée dans une branche dédiée.

Elle ne doit pas être fusionnée dans `dev` comme fonction opérationnelle sans indiquer clairement :

- qu’elle est expérimentale ;
- ce qui fonctionne ;
- ce qui manque ;
- comment la désactiver ;
- comment la supprimer proprement.

## Liste de contrôle avant pull request

- [ ] la branche correspond à un seul chantier principal ;
- [ ] aucun secret n’est présent ;
- [ ] les fichiers générés sont exclus ;
- [ ] les tests concernés passent ;
- [ ] Docker Compose est validé si modifié ;
- [ ] Helm est validé si modifié ;
- [ ] la documentation est à jour ;
- [ ] `make docs-check` passe si nécessaire ;
- [ ] `git diff --check` ne retourne aucune erreur ;
- [ ] le diff a été relu ;
- [ ] les limites sont expliquées ;
- [ ] la CI est prête à s’exécuter.

## Pages associées

- [Stratégie de branches](branching-strategy.md)
- [Règles de déploiement](deployment-rules.md)
- [Versions et releases](release-process.md)
- [Ajouter un service](../integrations/add-a-service.md)
- [Commandes disponibles](../getting-started/commands.md)
