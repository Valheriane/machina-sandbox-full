# Versions et releases

Cette page décrit le processus de versionnement et de release proposé pour **Machina Sandbox Full**.

Le projet ne possède actuellement :

- aucun tag Git ;
- aucune release GitHub identifiée ;
- aucune publication automatisée d’image ;
- aucune promotion formalisée vers un environnement de production.

Le processus décrit ici constitue donc une base progressive.

## Objectifs

Un processus de release doit permettre de :

- identifier précisément un état stable ;
- retrouver le code correspondant à un déploiement ;
- comprendre les changements ;
- préparer un retour arrière ;
- associer des images à une version ;
- éviter l’utilisation permanente de `latest` ;
- distinguer intégration et référence stable ;
- préparer une future automatisation GitOps.

## État actuel

La version du chart Helm est actuellement :

```text
0.1.0
```

La version applicative déclarée dans le chart est :

```text
1.0.0
```

Fleet API déclare également :

```text
0.1.0
```

dans son application FastAPI.

Le frontend déclare :

```text
0.0.0
```

dans `package.json`.

!!! warning "Versions non harmonisées"

    Les numéros présents dans les différents composants ne correspondent pas encore à une stratégie de release commune.

    Ils ne doivent pas être interprétés comme la preuve qu’une release officielle `1.0.0` existe.

## Tags Git

Aucun tag Git n’a été trouvé lors de l’audit.

La commande suivante est actuellement vide :

```bash
git tag --list
```

Le premier tag devra donc être créé seulement après définition et validation du processus.

## Version de projet

Pour le bac à sable complet, une version commune peut être utilisée :

```text
v0.1.0
v0.2.0
v0.3.0
```

Le préfixe `v` est utilisé pour les tags Git.

Exemple :

```text
v0.1.0
```

## Pourquoi commencer en `0.x`

Une version majeure `0` indique que le projet évolue encore fortement.

Cela correspond à l’état actuel :

- architecture expérimentale ;
- GitOps non stabilisé ;
- monitoring à réinstaller ;
- contrats MQTT non versionnés ;
- simulation générique ;
- absence de persistance Kubernetes complète ;
- configuration frontend à harmoniser ;
- tests encore partiels.

Une première version publique stable du bac à sable peut donc rester dans :

```text
0.x.y
```

## Versionnement sémantique proposé

Le format recommandé est :

```text
MAJEURE.MINEURE.CORRECTIF
```

Exemple :

```text
0.4.2
```

## Version majeure

La partie majeure augmente lorsqu’une rupture importante et stabilisée est introduite.

Exemple futur :

```text
1.0.0
```

Elle pourrait correspondre à un état où :

- les contrats sont stabilisés ;
- les déploiements sont reproductibles ;
- GitOps est opérationnel ;
- les principales fonctionnalités sont documentées ;
- les tests essentiels existent ;
- les secrets sont correctement gérés.

## Version mineure

La version mineure augmente lorsqu’une fonctionnalité est ajoutée sans correction urgente uniquement.

Exemple :

```text
0.2.0
```

pourrait introduire :

- un consommateur MQTT ;
- la séparation GPS et IoT ;
- le monitoring reproductible ;
- Argo CD ;
- un nouveau type de véhicule.

## Version corrective

La version corrective augmente pour une correction compatible.

Exemple :

```text
0.2.1
```

pourrait corriger :

- une route Fleet API ;
- un topic affiché ;
- une probe ;
- un script ;
- une erreur de documentation importante.

## Versions de prépublication

Des versions de test peuvent être utilisées plus tard :

```text
v0.2.0-alpha.1
v0.2.0-beta.1
v0.2.0-rc.1
```

Elles ne sont pas nécessaires pour chaque petite expérimentation.

Dans l’état actuel, les branches `feature/*` et `dev` suffisent généralement.

## Branche source d’une release

Une release stable doit être créée depuis :

```text
main
```

Le flux proposé est :

```text
feature/*
    |
    v
dev
    |
    v
main
    |
    v
tag
```

Une release ne doit pas être créée directement depuis une branche de fonctionnalité.

## Préparer une release

Avant une release, vérifier que :

- les changements prévus sont intégrés dans `dev` ;
- la CI passe ;
- les tests locaux nécessaires passent ;
- la documentation est à jour ;
- les limitations sont connues ;
- aucun secret n’est présent ;
- le chart Helm est valide ;
- Docker Compose est valide ;
- les migrations ou changements de configuration sont documentés.

## Promotion vers `main`

Créer une pull request :

```text
dev → main
```

La pull request doit résumer :

- les fonctionnalités ajoutées ;
- les corrections ;
- les changements incompatibles ;
- les modifications de configuration ;
- les changements Kubernetes ;
- les limites ;
- les validations exécutées.

## Contrôles avant fusion

### État Git

```bash
git status --short
```

### Documentation

```bash
make docs-check
```

### Diff

```bash
git diff --check
```

### Docker Compose

```bash
make compose-config
```

### Helm et Kubernetes

```bash
make validate-k8s
```

### Backend

```bash
Application/fleet-api/.venv/bin/python \
  -m pytest \
  Application/fleet-api/tests
```

### Frontend

```bash
cd Application/front
npm run lint
npm run build
```

La liste exacte dépend du contenu de la release.

## CI actuelle

La CI vérifie actuellement :

- les tests Fleet API ;
- la construction du frontend.

Elle ne valide pas encore automatiquement :

- MkDocs ;
- Docker Compose ;
- Helm ;
- kubeconform ;
- les manifests Argo CD ;
- le monitoring.

Une release doit donc conserver des validations locales complémentaires.

## Déterminer la version

Avant de modifier les fichiers de version, définir la prochaine version.

Exemple :

```text
Version précédente : aucune
Version proposée   : 0.1.0
```

ou :

```text
Version précédente : 0.2.0
Version proposée   : 0.3.0
```

## Fichiers de version à harmoniser

Une future release peut nécessiter la mise à jour de :

```text
Application/machina-sandbox/Chart.yaml
Application/fleet-api/main.py
Application/front/package.json
```

Cependant, il faut d’abord décider si tous les composants utilisent la même version.

## Version du chart Helm

Dans :

```text
Application/machina-sandbox/Chart.yaml
```

deux champs sont distincts :

```yaml
version: 0.1.0
appVersion: "1.0.0"
```

### `version`

`version` représente la version du chart Helm.

Elle doit augmenter lorsqu’un nouveau package du chart est créé.

### `appVersion`

`appVersion` représente la version de l’application déployée.

Elle est informative pour Helm et ne modifie pas automatiquement les images.

!!! warning "Chart et application"

    Modifier `appVersion` ne change pas les tags Docker.

    Les images doivent être configurées séparément dans `values.yaml` ou par surcharge.

## Version Fleet API

Fleet API déclare actuellement :

```python
FastAPI(
    title="Fleet API",
    version="0.1.0",
)
```

Cette valeur peut être alignée sur :

- la version du service ;
- ou la version globale de l’application.

Le choix n’est pas encore officialisé.

## Version frontend

Le frontend déclare actuellement :

```json
{
  "version": "0.0.0"
}
```

Cette valeur peut être mise à jour lors d’une release.

Elle n’est actuellement pas affichée dans l’interface.

## Tags d’images

Les images locales utilisent actuellement :

```text
fleet-api:latest
front:latest
```

Une future release devrait produire :

```text
fleet-api:0.1.0
front:0.1.0
```

ou :

```text
fleet-api:v0.1.0
front:v0.1.0
```

Une seule convention doit être choisie.

## Images immuables

Un environnement stable ne devrait pas dépendre uniquement de :

```text
latest
```

Avec une version explicite, il devient possible de savoir précisément quelle image est déployée.

Exemple :

```yaml
fleetApi:
  image:
    repository: fleet-api
    tag: "0.1.0"
```

## Images locales dans Minikube

Tant que les images ne sont pas publiées dans un registry, elles doivent être :

1. construites localement ;
2. taguées ;
3. chargées dans Minikube.

Le processus actuel utilise le tag `latest`.

L’évolution vers des tags de release devra modifier les cibles :

```text
devcont-build-images
devcont-load-images
devcont-deploy
```

## Registry futur

Un registry pourrait être ajouté plus tard.

Exemples possibles :

```text
GitHub Container Registry
registry local
autre registry privé
```

Aucun registry officiel n’est actuellement configuré dans la CI observée.

## Notes de release

Chaque release doit comporter un résumé des changements.

Structure possible :

```markdown
# Machina Sandbox Full 0.2.0

## Nouveautés

- ajout du consommateur MQTT ;
- ajout du monitoring reproductible.

## Corrections

- correction de la réponse de commande Fleet API ;
- correction du topic affiché dans le frontend.

## Changements de configuration

- nouvelle variable `MQTT_TOPIC`.

## Limites connues

- absence de persistance Kubernetes pour Fleet API.

## Mise à jour

- reconstruire les images ;
- exécuter `make devcont-deploy`.
```

## Changelog

Le dépôt ne contient actuellement aucun fichier `CHANGELOG.md` identifié.

Un changelog pourra être ajouté lorsque les releases commenceront réellement.

Structure possible :

```text
CHANGELOG.md
```

Il pourra suivre des sections comme :

```text
Added
Changed
Fixed
Removed
Security
```

## Préparer le commit de release

Exemple de message :

```text
chore(release): prepare v0.1.0
```

Ce commit peut contenir :

- les numéros de version ;
- le changelog ;
- la documentation ;
- les fichiers de configuration nécessaires.

Il ne doit pas introduire une nouvelle fonctionnalité non testée.

## Créer un tag

Après fusion dans `main`, mettre à jour la branche locale :

```bash
git switch main
git pull --ff-only
```

Vérifier le commit :

```bash
git log -1 --oneline
```

Créer un tag annoté :

```bash
git tag \
  --annotate v0.1.0 \
  --message "Machina Sandbox Full v0.1.0"
```

## Vérifier le tag

```bash
git show v0.1.0
```

## Publier le tag

```bash
git push origin v0.1.0
```

!!! warning "Avant le push"

    Un tag publié doit être considéré comme immuable.

    Vérifier soigneusement :

    - le commit ciblé ;
    - la version ;
    - les tests ;
    - la documentation.

## Ne pas déplacer un tag publié

Éviter de supprimer puis recréer un tag déjà partagé.

Une erreur dans une release doit normalement produire une nouvelle version :

```text
v0.1.1
```

plutôt que déplacer :

```text
v0.1.0
```

## Release GitHub

Une release GitHub peut être créée à partir du tag.

Elle peut contenir :

- le titre ;
- les notes de release ;
- les limites connues ;
- les instructions de mise à jour ;
- les liens vers la documentation.

Aucune automatisation de release GitHub n’est actuellement présente dans :

```text
.github/workflows/ci.yml
```

## Déploiement d’une release

Dans l’état actuel, créer un tag ne déploie rien automatiquement.

Le déploiement reste manuel :

```bash
make devcont-deploy
```

La future stratégie GitOps pourra associer :

- `dev` à un environnement d’intégration ;
- `main` à un environnement stable ;
- un tag à une release immuable.

Cette correspondance n’est pas encore mise en œuvre.

## GitOps basé sur une branche

Les manifests Argo CD existants utilisent actuellement :

```text
dev
```

ou :

```text
main
```

Ils ne suivent aucun tag.

Argo CD peut suivre une branche, un tag ou un commit, mais une stratégie unique devra être choisie.

## Stratégie possible à court terme

| Usage                      | Révision Git |
| -------------------------- | ------------ |
| intégration future         | `dev`        |
| référence stable future    | `main`       |
| reproduction d’une release | tag `vX.Y.Z` |

Une Application Argo CD d’intégration peut suivre `dev`.

Une Application stable pourrait suivre `main` ou une version précise.

## Retour arrière Git

Lorsqu’une régression est découverte après une fusion :

- créer un commit correctif ;
- ou utiliser `git revert`.

Exemple :

```bash
git revert <commit>
```

Éviter de réécrire l’historique de `main`.

## Retour arrière Helm

Afficher les révisions :

```bash
helm history machina-sandbox \
  --namespace machina-sandbox
```

Puis, après vérification :

```bash
helm rollback machina-sandbox <revision> \
  --namespace machina-sandbox
```

Le rollback Helm ne modifie pas Git.

Dans un fonctionnement GitOps, Argo CD peut ensuite réappliquer l’état présent dans Git.

## Retour arrière GitOps

Une stratégie GitOps privilégie un changement versionné :

1. identifier la régression ;
2. rétablir une configuration valide dans Git ;
3. créer une pull request corrective ;
4. fusionner ;
5. laisser Argo CD synchroniser.

Pour une urgence, une synchronisation vers un commit ou un tag antérieur peut être envisagée, mais doit être documentée.

## Données et rollback

Un retour arrière du code ne garantit pas la compatibilité avec les données.

Points à vérifier :

- schéma SQLite ;
- ConfigMaps ;
- Secrets ;
- volumes persistants ;
- formats MQTT ;
- contrats API ;
- données générées par une version plus récente.

Le projet ne contient actuellement aucune migration structurée de base de données.

## Release de documentation

Une modification uniquement documentaire peut être fusionnée sans créer systématiquement une nouvelle release applicative.

Une release devient utile lorsque la documentation décrit un nouvel état stable du projet ou accompagne une fonctionnalité publiée.

## Correction urgente

Une correction urgente peut suivre :

```text
main
 |
 v
fix/description
 |
 v
pull request vers main
 |
 v
nouvelle version corrective
```

Le correctif doit ensuite être réintégré dans :

```text
dev
```

afin d’éviter que la correction disparaisse lors d’une future promotion.

## Branches `prod` et `test`

Les branches :

```text
prod
test
```

existent actuellement, mais leur rôle n’est pas défini.

Elles ne doivent pas être intégrées au processus de release avant clarification.

Une release ne doit pas être créée simplement en fusionnant vers `prod` sans procédure documentée.

## Liste de contrôle de release

### Code

- [ ] fonctionnalités prévues terminées ;
- [ ] corrections incluses ;
- [ ] aucun secret versionné ;
- [ ] dépendances vérifiées ;
- [ ] fichiers générés exclus.

### Tests

- [ ] tests Fleet API réussis ;
- [ ] frontend construit ;
- [ ] lint frontend vérifié si nécessaire ;
- [ ] Docker Compose validé ;
- [ ] chart Helm validé ;
- [ ] test Minikube effectué si nécessaire.

### Documentation

- [ ] documentation mise à jour ;
- [ ] limites connues documentées ;
- [ ] instructions de mise à jour présentes ;
- [ ] `make docs-check` réussi ;
- [ ] `git diff --check` réussi.

### Version

- [ ] numéro choisi ;
- [ ] `Chart.yaml` mis à jour si nécessaire ;
- [ ] version Fleet API mise à jour si nécessaire ;
- [ ] version frontend mise à jour si nécessaire ;
- [ ] tags d’images définis si utilisés ;
- [ ] notes de release préparées.

### Git

- [ ] pull request `dev → main` validée ;
- [ ] CI réussie ;
- [ ] branche `main` à jour ;
- [ ] commit ciblé vérifié ;
- [ ] tag annoté créé ;
- [ ] tag publié.

### Déploiement

- [ ] procédure de déploiement connue ;
- [ ] retour arrière identifié ;
- [ ] données vérifiées ;
- [ ] état des pods contrôlé ;
- [ ] logs contrôlés ;
- [ ] version réellement déployée identifiable.

## Premier jalon proposé

Une première release pourrait être créée lorsque les éléments suivants seront stabilisés :

- Dev Container reproductible ;
- déploiement Minikube reproductible ;
- documentation principale complète ;
- CI backend et frontend fonctionnelle ;
- chart Helm validé ;
- monitoring et GitOps clairement identifiés comme présents ou absents ;
- aucune information sensible versionnée.

La version exacte devra être choisie au moment de cette validation.

## État actuel résumé

| Élément             | État            |
| ------------------- | --------------- |
| tags Git            | absents         |
| releases GitHub     | non identifiées |
| version globale     | non harmonisée  |
| images versionnées  | absentes        |
| registry            | non configuré   |
| déploiement par tag | absent          |
| changelog           | absent          |
| release automatisée | absente         |
| versionnement `0.x` | recommandé      |
| procédure proposée  | documentée      |

## Décisions restantes

Le processus devra être mis à jour lorsque les points suivants seront décidés :

- première version officielle ;
- version commune ou versions par service ;
- format des tags d’images ;
- registry ;
- automatisation GitHub Actions ;
- génération du changelog ;
- stratégie Argo CD par branche ou par tag ;
- rôle des branches `prod` et `test` ;
- procédure stable de rollback ;
- stratégie de migration des données.

## Pages associées

- [Stratégie de branches](branching-strategy.md)
- [Règles de contribution](contribution-rules.md)
- [Règles de déploiement](deployment-rules.md)
- [Commandes disponibles](../getting-started/commands.md)
- [Environnements](../architecture/environments.md)
