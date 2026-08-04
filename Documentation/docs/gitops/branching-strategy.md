# Stratégie de branches

Cette page décrit la stratégie Git proposée pour **Machina Sandbox Full**.

Le projet étant un bac à sable en évolution, cette stratégie reste volontairement simple. Elle doit faciliter l’apprentissage, les expérimentations, les validations et la future mise en place de GitOps sans imposer immédiatement un processus de production complexe.

## Objectifs

La stratégie de branches doit permettre de :

- protéger une version de référence du projet ;
- intégrer progressivement les nouvelles fonctionnalités ;
- isoler les expérimentations ;
- faciliter la revue des changements ;
- exécuter la CI avant les intégrations importantes ;
- éviter qu’une branche expérimentale modifie automatiquement Kubernetes ;
- préparer une future synchronisation avec Argo CD ;
- conserver un historique compréhensible.

## État actuellement observé

Les branches principales présentes dans le dépôt sont notamment :

```text
main
dev
prod
test
```

Plusieurs branches de travail existent également :

```text
feature/devcontainer
feature/sandbox-documentation
feature/ci-and-secrets
feature/correction-loki-minikube
feature/script
feature/test-back
```

Une branche de sauvegarde est aussi présente :

```text
backup/dev-before-align
```

Aucun tag Git n’a été trouvé lors de l’audit.

!!! info "Branches en évolution"

    La présence d’une branche ne signifie pas automatiquement qu’elle possède encore un rôle actif.

    Les branches `prod`, `test` et `backup/*` doivent être considérées comme historiques ou expérimentales tant que leur fonction n’a pas été explicitement confirmée.

## Historique récent observé

L’historique montre un fonctionnement proche du schéma suivant :

```text
feature/*
    |
    v
dev
    |
    v
main
```

Par exemple, la préparation du Dev Container a été réalisée dans :

```text
feature/devcontainer
```

puis intégrée dans :

```text
dev
```

La documentation est actuellement développée dans :

```text
feature/sandbox-documentation
```

La pratique observée correspond donc déjà en partie à une stratégie basée sur des branches de fonctionnalités.

## Stratégie proposée

À court terme, le projet peut utiliser les catégories suivantes :

| Type        | Rôle                                                  |
| ----------- | ----------------------------------------------------- |
| `main`      | version stable de référence du bac à sable            |
| `dev`       | branche d’intégration des changements validés         |
| `feature/*` | développement d’une fonctionnalité ou d’un chantier   |
| `fix/*`     | correction ciblée                                     |
| `docs/*`    | documentation uniquement, si une séparation est utile |
| `backup/*`  | sauvegarde temporaire exceptionnelle                  |
| `prod`      | rôle non défini pour le moment                        |
| `test`      | rôle non défini pour le moment                        |

## Branche `main`

`main` représente la version de référence la plus stable du dépôt.

Elle doit contenir une version :

- compréhensible ;
- validée par la CI ;
- documentée ;
- déployable dans le bac à sable ;
- sans secret versionné ;
- sans expérimentation incomplète activée par défaut.

!!! note "Stable ne signifie pas production"

    Machina Sandbox Full reste un environnement expérimental.

    La branche `main` représente une référence stable du bac à sable, mais ne constitue pas nécessairement une version prête pour un environnement de production réel.

Les modifications directes sur `main` doivent être évitées.

Le flux recommandé est :

```text
feature/*
    |
    v
dev
    |
    v
main
```

## Branche `dev`

`dev` est la branche d’intégration.

Elle reçoit les fonctionnalités qui :

- fonctionnent localement ;
- ont passé leurs tests principaux ;
- ne contiennent pas de secret ;
- ne cassent pas volontairement le projet ;
- sont suffisamment documentées pour être comprises ;
- peuvent encore nécessiter une validation globale avant `main`.

`dev` peut évoluer plus rapidement que `main`.

Elle peut contenir des changements en cours de stabilisation, mais elle ne doit pas devenir une accumulation de code volontairement cassé.

## Branches `feature/*`

Une branche de fonctionnalité isole un chantier précis.

Exemples :

```text
feature/devcontainer
feature/sandbox-documentation
feature/telemetry-consumer
feature/monitoring-bootstrap
feature/argocd-installation
```

Une branche `feature/*` doit normalement être créée depuis `dev`.

```bash
git switch dev
git pull --ff-only
git switch -c feature/nom-du-chantier
```

!!! warning "Vérifier avant de créer"

    Avant de créer une branche, vérifier l’état du dépôt :

    ```bash
    git status --short
    ```

    Les modifications non enregistrées doivent être comprises avant de changer de branche.

## Branches `fix/*`

Une branche de correction peut être utilisée lorsqu’un problème précis doit être isolé.

Exemples :

```text
fix/frontend-runtime-config
fix/mqtt-readiness
fix/minikube-host-helper
```

Dans la majorité des cas, elle est créée depuis `dev`.

```bash
git switch dev
git pull --ff-only
git switch -c fix/description-courte
```

Une correction urgente appliquée directement depuis `main` devra ensuite être réintégrée dans `dev`.

Cette procédure reste exceptionnelle dans le contexte actuel du bac à sable.

## Branches `docs/*`

La documentation peut continuer à utiliser une branche `feature/*`, comme :

```text
feature/sandbox-documentation
```

Une catégorie `docs/*` peut être introduite plus tard si elle améliore la lisibilité.

Exemple :

```text
docs/operations
docs/gitops
docs/architecture-update
```

Il n’est pas nécessaire d’utiliser simultanément deux conventions pour le même besoin.

## Branches `backup/*`

Les branches `backup/*` sont réservées à des situations exceptionnelles :

- conservation temporaire avant une opération risquée ;
- récupération d’un historique ;
- comparaison entre deux états ;
- sauvegarde avant réalignement.

Elles ne doivent pas devenir des branches de développement permanentes.

Une branche de sauvegarde doit idéalement indiquer sa raison :

```text
backup/dev-before-align
backup/main-before-history-repair
```

!!! warning "Une branche ne remplace pas une sauvegarde"

    Une branche Git conserve un état versionné, mais ne remplace pas :

    - une sauvegarde du dépôt ;
    - la copie de fichiers non suivis ;
    - la sauvegarde des bases de données ;
    - la sauvegarde du cluster ;
    - la sauvegarde des secrets.

## Branches `prod` et `test`

Les branches suivantes existent actuellement :

```text
prod
test
```

L’audit ne permet pas de confirmer qu’elles possèdent encore un rôle actif.

Elles ne doivent donc pas être utilisées comme source GitOps automatique tant que les questions suivantes ne sont pas résolues :

- quel environnement représente `test` ?
- quel environnement représente `prod` ?
- les branches doivent-elles être permanentes ?
- quelle branche reçoit les corrections ?
- comment les changements sont-ils promus ?
- quelle CI est obligatoire ?
- quelles ressources Kubernetes sont concernées ?
- existe-t-il réellement un environnement de production ?

!!! danger "Ne pas supprimer immédiatement"

    Ces branches peuvent contenir un historique utile.

    Elles ne doivent pas être supprimées ou réalignées sans inspection complémentaire et sans accord explicite.

## Cycle d’une fonctionnalité

Le cycle recommandé est :

```text
Créer depuis dev
      |
      v
Développer
      |
      v
Tester localement
      |
      v
Mettre à jour la documentation
      |
      v
Pousser la branche
      |
      v
Ouvrir une pull request vers dev
      |
      v
Vérifier la CI
      |
      v
Fusionner dans dev
```

Lorsque plusieurs changements intégrés dans `dev` sont considérés comme stables :

```text
dev
 |
 v
pull request
 |
 v
main
```

## Création d’une branche

Depuis la racine du dépôt :

```bash
git status --short
git switch dev
git pull --ff-only
git switch -c feature/nom-du-chantier
```

Exemple :

```bash
git switch -c feature/monitoring-bootstrap
```

## Publication d’une branche

Pour publier une nouvelle branche :

```bash
git push --set-upstream origin HEAD
```

Cette commande évite de recopier manuellement le nom de la branche.

## Mise à jour depuis `dev`

Avant une pull request, une branche peut récupérer les évolutions récentes de `dev`.

### Avec une fusion

```bash
git fetch origin
git merge origin/dev
```

Cette méthode conserve explicitement la fusion dans l’historique.

### Avec un rebase

```bash
git fetch origin
git rebase origin/dev
```

Le rebase réécrit les commits locaux de la branche.

!!! warning "Ne pas rebase une branche partagée sans coordination"

    Un rebase peut modifier l’historique déjà publié.

    Pendant l’apprentissage ou lorsqu’une branche est utilisée par plusieurs personnes, une fusion est souvent plus simple et plus sûre.

## Vérifications avant publication

Avant un push ou une pull request :

```bash
git status --short
git diff --check
```

Selon les fichiers modifiés, exécuter également :

```bash
make docs-check
make compose-config
make validate-k8s
```

Pour Fleet API :

```bash
Application/fleet-api/.venv/bin/python \
  -m pytest \
  Application/fleet-api/tests
```

Pour le frontend :

```bash
cd Application/front
npm run lint
npm run build
```

Les validations réellement nécessaires dépendent du chantier.

## Intégration continue actuelle

Le workflow :

```text
.github/workflows/ci.yml
```

est actuellement déclenché pour :

- les push sur `main` ;
- les push sur `dev` ;
- les pull requests.

Les jobs actifs vérifient notamment :

- les tests de Fleet API ;
- la construction du frontend.

Un smoke test Docker Compose est présent dans le fichier, mais il est actuellement commenté.

!!! info "CI encore incomplète"

    La CI ne valide pas encore automatiquement l’ensemble des éléments suivants :

    - Docker Compose ;
    - le chart Helm ;
    - kubeconform ;
    - la documentation MkDocs ;
    - les manifests Argo CD ;
    - l’installation du monitoring ;
    - le simulateur autonome.

    Ces contrôles pourront être ajoutés progressivement.

## Pull requests

Les intégrations importantes devraient passer par une pull request.

### Cible habituelle

Une branche de travail cible normalement :

```text
dev
```

Une promotion stable cible :

```text
main
```

### Contenu attendu

Une pull request doit expliquer :

- le problème ou l’objectif ;
- les fichiers principaux modifiés ;
- les tests exécutés ;
- les limites connues ;
- les conséquences sur Docker Compose ;
- les conséquences sur Kubernetes ;
- les changements de configuration ;
- les changements de documentation ;
- les éventuels travaux restant à faire.

## Taille des branches

Une branche doit rester centrée sur un objectif identifiable.

Exemples de chantiers séparés :

```text
feature/monitoring-bootstrap
feature/argocd-installation
feature/telemetry-consumer
docs/gitops
```

Il est préférable d’éviter une branche qui modifie simultanément :

- le monitoring ;
- Argo CD ;
- Fleet API ;
- le frontend ;
- tous les contrats MQTT ;
- toute la documentation ;

sans raison commune claire.

## Nommage

Les noms doivent être :

- en minuscules ;
- sans espace ;
- courts mais explicites ;
- séparés par des tirets.

Exemples recommandés :

```text
feature/runtime-config
fix/loki-readiness
docs/gitops-rules
```

Exemples à éviter :

```text
feature/test
nouvelle-branche
correction2
essai-final-v3
```

## Commits

L’historique récent utilise partiellement une convention de type :

```text
type(scope): description
```

Exemples :

```text
feat(devcontainer): add simplified Minikube workflows
fix(host): mark helper as executable
refactor(project): reorganize application and initialize documentation
```

Cette convention peut être progressivement généralisée.

Types possibles :

| Type       | Usage                                            |
| ---------- | ------------------------------------------------ |
| `feat`     | nouvelle fonctionnalité                          |
| `fix`      | correction                                       |
| `docs`     | documentation                                    |
| `test`     | tests                                            |
| `refactor` | réorganisation sans changement fonctionnel voulu |
| `build`    | construction et dépendances                      |
| `ci`       | intégration continue                             |
| `chore`    | maintenance                                      |
| `style`    | format sans changement fonctionnel               |

Exemples :

```text
docs(gitops): document branch strategy
feat(monitoring): add reproducible bootstrap
fix(front): correct telemetry topic display
ci(helm): validate rendered manifests
```

!!! note "Progression et non blocage"

    Les anciens commits utilisent plusieurs styles et plusieurs langues.

    Ils n’ont pas besoin d’être réécrits.

    La convention doit surtout améliorer les nouveaux commits.

## Commits courts et cohérents

Un commit doit représenter une unité compréhensible.

Éviter de mélanger dans un même commit :

- une correction de code ;
- un changement de secret ;
- une réorganisation complète ;
- une documentation sans rapport ;
- des fichiers générés.

Un historique lisible facilite :

- les revues ;
- les retours en arrière ;
- les recherches ;
- le diagnostic ;
- la préparation des releases.

## Fichiers générés

Les fichiers générés ne doivent généralement pas être versionnés.

Exemples :

```text
Documentation/site/
Application/front/dist/
__pycache__/
.pytest_cache/
*.db
```

Les exceptions doivent être justifiées.

## Secrets

Aucun secret ne doit être intégré à une branche.

Cela concerne notamment :

```text
SHARED_SECRET
MQTT_PASSWORD
mot de passe Grafana
mot de passe Argo CD
token GitHub
clé d’accès
fichier kubeconfig
```

Avant un commit :

```bash
git diff --cached
```

Cette commande permet de relire exactement ce qui sera enregistré.

## GitOps et branches

Argo CD ne doit pas suivre automatiquement toutes les branches.

Une branche `feature/*` ne doit pas devenir une source de déploiement automatique par défaut.

Le principe recommandé est :

| Environnement                   | Branche possible |
| ------------------------------- | ---------------- |
| expérimentation locale manuelle | branche courante |
| intégration GitOps future       | `dev`            |
| référence stable future         | `main`           |

Cette correspondance n’est pas encore finalisée.

## Manifests Argo CD actuellement présents

Le dépôt contient plusieurs essais.

### Application Helm

```text
Application/k8s/argocd/app-helm.yaml
```

Cette Application utilise actuellement :

```text
targetRevision: dev
path: Application/machina-sandbox
namespace: machina-helm-test
```

Elle active :

```text
prune: true
selfHeal: true
```

### ApplicationSet

```text
Application/k8s/argocd/applicationset-machina.yaml
```

Cet ApplicationSet utilise actuellement :

```text
targetRevision: main
path: Application/k8s/apps/*
namespace: machina-sandbox
```

Il active également :

```text
prune: true
selfHeal: true
```

### Application de test

```text
Application/app-test.yaml
```

Elle utilise actuellement :

```text
targetRevision: main
path: Application/k8s
namespace: machina-sandbox
```

## Incohérences GitOps à résoudre

Les manifests actuels utilisent simultanément :

- `dev` et `main` ;
- le chart Helm et les manifests historiques ;
- `machina-helm-test` et `machina-sandbox` ;
- une Application unique et un ApplicationSet ;
- plusieurs chemins pouvant décrire la même application.

!!! danger "Ne pas appliquer les trois configurations ensemble"

    Ces manifests peuvent entrer en concurrence.

    Deux applications Argo CD ne doivent pas tenter de gérer les mêmes ressources Kubernetes avec des sources différentes.

    Les manifests existants doivent être considérés comme des expérimentations jusqu’à la définition d’une source de vérité unique.

## Source de vérité recommandée

Pour l’application principale, la source la plus récente actuellement identifiée est :

```text
Application/machina-sandbox/
```

Le chart Helm est déjà utilisé par :

```bash
make devcont-deploy
```

Les manifests situés dans :

```text
Application/k8s/apps/
```

doivent être audités avant d’être conservés comme seconde méthode de déploiement.

À terme, Argo CD devrait suivre une seule source principale pour une même application.

## Déploiement manuel et GitOps

Tant qu’Argo CD n’est pas remis en place, le déploiement actuel reste piloté manuellement avec Helm :

```bash
make devcont-deploy
```

Lorsque GitOps sera activé, il faudra éviter de modifier manuellement des ressources gérées par Argo CD sans comprendre les conséquences.

Avec :

```text
selfHeal: true
```

Argo CD peut annuler une modification manuelle.

Avec :

```text
prune: true
```

Argo CD peut supprimer une ressource qui n’existe plus dans Git.

## Protection recommandée des branches

Lorsque la configuration GitHub sera stabilisée, les protections suivantes pourront être ajoutées à `main` :

- pull request obligatoire ;
- CI obligatoire ;
- interdiction de suppression ;
- interdiction des force-push ;
- historique à jour avant fusion.

Pour `dev`, une protection plus légère peut être utilisée :

- CI obligatoire ;
- force-push interdit ;
- suppression interdite ;
- pull request recommandée.

Ces protections ne sont pas confirmées comme actuellement configurées.

## Force-push

Éviter :

```bash
git push --force
```

Lorsqu’un force-push est réellement nécessaire sur une branche personnelle, préférer :

```bash
git push --force-with-lease
```

Cette commande réduit le risque d’écraser des commits distants inconnus.

Elle ne doit pas être utilisée sur :

```text
main
dev
```

## Suppression d’une branche fusionnée

Après validation et fusion :

```bash
git branch --merged
```

Pour supprimer une branche locale fusionnée :

```bash
git branch -d feature/nom-du-chantier
```

Pour supprimer la branche distante :

```bash
git push origin \
  --delete feature/nom-du-chantier
```

Ne pas supprimer une branche tant que son intégration n’est pas confirmée.

## Cas de la branche actuelle

La branche actuelle est :

```text
feature/sandbox-documentation
```

Elle contient la préparation de la documentation MkDocs.

Le parcours recommandé est :

1. terminer les pages prévues ;
2. lancer `make docs-check` ;
3. lancer `git diff --check` ;
4. relire les fichiers modifiés ;
5. pousser la branche ;
6. créer une pull request vers `dev` ;
7. vérifier la CI ;
8. fusionner après validation.

## Stratégie provisoire résumée

```text
main
  |
  | référence stable
  |
dev
  |
  | intégration
  |
feature/*  fix/*  docs/*
```

Les branches suivantes restent à clarifier :

```text
prod
test
backup/*
```

Les manifests Argo CD restent également à harmoniser avant activation.

## Décisions restant à prendre

La stratégie devra être mise à jour lorsque les points suivants seront décidés :

- rôle définitif de `prod` ;
- rôle définitif de `test` ;
- protections GitHub ;
- stratégie de tags ;
- stratégie de release ;
- branche suivie par Argo CD ;
- environnement associé à `dev` ;
- environnement associé à `main` ;
- source de vérité entre Helm et les manifests historiques ;
- politique de synchronisation automatique ;
- procédure de retour arrière.

## Pages associées

- [Règles de contribution](contribution-rules.md)
- [Règles de déploiement](deployment-rules.md)
- [Versions et releases](release-process.md)
- [Commandes disponibles](../getting-started/commands.md)
- [Ajouter un service](../integrations/add-a-service.md)
