# Airflow

Apache Airflow est envisagé comme une intégration future de **Machina Sandbox Full** afin d’expérimenter l’orchestration de traitements planifiés sur les données produites par les drones simulés.

!!! warning "Airflow n’est pas encore intégré"

    Airflow n’est actuellement :

    - ni présent comme service applicatif dans le dépôt ;
    - ni déclaré dans Docker Compose ;
    - ni déployé par le chart Helm principal ;
    - ni installé dans Minikube ;
    - ni utilisé par la CI ;
    - ni nécessaire au fonctionnement du bac à sable.

    Cette page décrit une orientation possible et non une fonctionnalité opérationnelle.

## Rôle envisagé

Airflow pourrait être utilisé pour orchestrer des traitements comme :

- agréger la télémétrie par heure ou par jour ;
- calculer des statistiques sur les trajectoires ;
- produire des rapports de consommation ;
- nettoyer ou archiver les anciennes données ;
- vérifier la qualité des données ;
- détecter des périodes sans télémétrie ;
- générer des exports ;
- préparer des jeux de données ;
- coordonner plusieurs étapes de transformation ;
- rejouer certains traitements sur une période donnée.

## Ce qu’Airflow ne remplacerait pas

Airflow ne remplacerait pas nécessairement :

- le broker MQTT ;
- Fleet API ;
- les simulateurs de drones ;
- le frontend ;
- un consommateur MQTT temps réel ;
- une base de données ;
- un système de streaming.

Le broker MQTT transporte les messages en temps réel.

Un consommateur spécialisé peut les recevoir et les enregistrer.

Airflow peut ensuite orchestrer des traitements sur les données déjà stockées.

## Architecture envisagée

```text
Simulateurs de drones
          |
          | télémétrie MQTT
          v
     Broker Mosquitto
          |
          v
Consommateur de télémétrie
          |
          | validation et stockage
          v
    Base de données
          |
          v
        Airflow
          |
          +--> agrégation
          +--> contrôle qualité
          +--> rapports
          +--> archivage
          +--> export
```

Dans cette architecture :

1. les drones publient leur télémétrie ;
2. un consommateur MQTT reçoit les messages ;
3. les données sont validées et enregistrées ;
4. Airflow exécute des traitements planifiés sur les données stockées.

## MQTT et Airflow

Les messages MQTT actuels sont publiés en continu sur :

```text
lab/drone/{drone_id}/telemetry
```

Airflow est principalement adapté à l’orchestration de tâches planifiées ou déclenchées autour de traitements identifiables.

Il n’est pas nécessairement le meilleur composant pour maintenir directement une connexion MQTT permanente.

Une séparation possible serait :

| Composant         | Responsabilité                                  |
| ----------------- | ----------------------------------------------- |
| Broker MQTT       | transporter les messages                        |
| Consommateur MQTT | recevoir et enregistrer les messages en continu |
| Stockage          | conserver la télémétrie                         |
| Airflow           | orchestrer les traitements périodiques          |

!!! info "Temps réel et traitement par lot"

    Le consommateur MQTT appartient au chemin temps réel.

    Airflow peut intervenir ensuite pour les traitements différés, les agrégations et les opérations planifiées.

## Exemples de traitements

### Rapport quotidien de flotte

Un traitement quotidien pourrait calculer :

- le nombre de drones actifs ;
- le nombre de messages reçus ;
- la distance approximative parcourue ;
- la consommation moyenne de batterie ;
- les périodes sans télémétrie ;
- les erreurs détectées ;
- les commandes envoyées.

### Agrégation de la télémétrie

La télémétrie brute peut être fréquente.

Un DAG pourrait produire :

- une moyenne par minute ;
- une moyenne par heure ;
- une position représentative ;
- une vitesse minimale et maximale ;
- une consommation cumulée ;
- un nombre de messages par drone.

### Contrôle de qualité

Un traitement pourrait rechercher :

- des coordonnées invalides ;
- une batterie hors limites ;
- un cap incohérent ;
- un horodatage trop ancien ;
- un changement de position impossible ;
- un identifiant absent ;
- une rupture de séquence ;
- un format de message inconnu.

### Archivage

Un DAG pourrait :

1. sélectionner les données anciennes ;
2. les exporter dans un format d’archive ;
3. vérifier le résultat ;
4. supprimer les données intermédiaires ;
5. conserver un journal de l’opération.

### Séparation GPS et IoT

Lorsque la télémétrie sera séparée en plusieurs familles :

```text
lab/drone/{drone_id}/telemetry/gps
lab/drone/{drone_id}/telemetry/iot
lab/drone/{drone_id}/telemetry/energy
```

Airflow pourrait lancer des traitements différents selon les données stockées :

- trajectoires pour le GPS ;
- statistiques de capteurs pour l’IoT ;
- suivi d’autonomie pour l’énergie.

## Concepts Airflow utiles

### DAG

Un DAG décrit un flux de traitement et les dépendances entre ses tâches.

Exemple conceptuel :

```text
extraire les données
        |
        v
valider les données
        |
        v
calculer les agrégations
        |
        +--> enregistrer en base
        |
        +--> produire un export
```

### Tâche

Une tâche représente une opération précise, par exemple :

- lire des données ;
- exécuter une requête ;
- produire un fichier ;
- appeler une API ;
- lancer un script Python ;
- vérifier une condition.

### Planification

Un DAG peut être exécuté :

- selon un calendrier ;
- manuellement ;
- lors d’un rejeu ;
- à partir d’une période de données ;
- après la fin d’un autre traitement.

### Rejeu

Airflow peut faciliter la réexécution d’un traitement sur une période historique.

Cette capacité peut être intéressante pour :

- recalculer des statistiques ;
- corriger une transformation ;
- reconstruire un rapport ;
- tester une nouvelle règle ;
- analyser un scénario simulé.

## Premier cas d’usage conseillé

La première expérimentation Airflow pourrait rester très simple.

Objectif :

```text
Produire chaque jour un résumé de la télémétrie stockée.
```

Étapes possibles :

1. lire les données de la veille ;
2. compter les messages ;
3. regrouper les données par drone ;
4. calculer la batterie minimale et moyenne ;
5. calculer la vitesse moyenne ;
6. enregistrer un résumé ;
7. écrire un rapport dans les logs.

Ce premier DAG permettrait de tester Airflow sans l’ajouter immédiatement au fonctionnement principal de l’application.

## Exemple conceptuel de DAG

Le code suivant est uniquement illustratif.

Il ne correspond pas à un fichier actuellement présent dans le dépôt.

```python
from datetime import datetime

from airflow.decorators import dag, task


@dag(
    schedule="@daily",
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=["machina", "telemetry"],
)
def daily_telemetry_summary():

    @task
    def extract() -> list[dict]:
        # Lire les données enregistrées par le consommateur MQTT.
        return []

    @task
    def validate(rows: list[dict]) -> list[dict]:
        # Écarter ou signaler les données invalides.
        return rows

    @task
    def aggregate(rows: list[dict]) -> dict:
        # Calculer les statistiques par drone.
        return {
            "messages": len(rows),
        }

    @task
    def save(summary: dict) -> None:
        # Enregistrer ou exporter le résumé.
        print(summary)

    rows = extract()
    valid_rows = validate(rows)
    summary = aggregate(valid_rows)
    save(summary)


daily_telemetry_summary()
```

!!! note "Exemple incomplet"

    Cet exemple montre seulement l’organisation possible d’un DAG.

    Il ne définit pas encore :

    - la base de données ;
    - les connexions Airflow ;
    - la gestion des erreurs ;
    - les tests ;
    - les volumes ;
    - l’authentification ;
    - les métriques ;
    - la stratégie de déploiement.

## Stockage préalable

Airflow aurait besoin d’une source de données stable.

Le projet ne possède actuellement pas de stockage dédié à la télémétrie.

Plusieurs options pourront être expérimentées.

### PostgreSQL

PostgreSQL peut conserver :

- les drones ;
- les positions ;
- les mesures ;
- les événements ;
- les agrégations ;
- les résultats des traitements.

### Base de séries temporelles

Une base spécialisée peut faciliter :

- les données fréquentes ;
- les agrégations temporelles ;
- les politiques de rétention ;
- les graphiques ;
- les requêtes par période.

### Fichiers

Le consommateur MQTT pourrait produire temporairement :

```text
JSON Lines
CSV
Parquet
```

Airflow pourrait ensuite lire et transformer ces fichiers.

!!! warning "SQLite"

    SQLite est adaptée aux prototypes locaux et à Fleet API dans son état actuel.

    Elle peut devenir limitante lorsque plusieurs services ou tâches Airflow écrivent simultanément.

## Organisation possible dans le dépôt

Une future expérimentation pourrait être isolée dans :

```text
Application/airflow/
```

Exemple d’arborescence :

```text
Application/airflow/
├── dags/
│   └── daily_telemetry_summary.py
├── plugins/
├── tests/
│   └── test_daily_telemetry_summary.py
├── config/
├── Dockerfile
├── docker-compose.airflow.yml
├── requirements-airflow.txt
└── README.md
```

!!! info "Isolation recommandée"

    Airflow possède plusieurs composants et dépendances.

    Il est préférable de commencer avec un environnement isolé plutôt que de l’ajouter directement au fichier Compose principal.

## Pourquoi un fichier Compose séparé

Une première expérimentation pourrait utiliser :

```text
Application/airflow/docker-compose.airflow.yml
```

Cela permettrait de démarrer Airflow indépendamment de :

```text
Application/docker-compose.yml
```

Avantages :

- ne pas alourdir le démarrage normal ;
- ne pas rendre Airflow obligatoire ;
- conserver une expérimentation réversible ;
- séparer les volumes ;
- séparer la base de métadonnées ;
- tester plusieurs configurations.

## Composants Airflow possibles

Une installation Airflow peut nécessiter plusieurs composants.

| Composant           | Rôle                                      |
| ------------------- | ----------------------------------------- |
| Webserver           | interface d’administration                |
| Scheduler           | planification des DAGs                    |
| Base de métadonnées | état des exécutions et tâches             |
| Worker              | exécution des tâches selon le mode choisi |
| Triggerer           | gestion de certains traitements différés  |

La composition exacte dépendra de l’exécuteur retenu et du niveau de complexité souhaité.

Pour une première expérimentation, il faudra privilégier la configuration la plus simple compatible avec l’objectif.

## Base de métadonnées Airflow

La base de métadonnées Airflow est différente de la base contenant la télémétrie.

Elle conserve notamment :

- les DAGs connus ;
- les exécutions ;
- les tâches ;
- leurs états ;
- les planifications ;
- les connexions ;
- certaines configurations.

Il faut distinguer :

```text
Base Airflow
```

et :

```text
Base de télémétrie Machina
```

!!! warning "Ne pas mélanger les responsabilités"

    La base de métadonnées Airflow ne doit pas être utilisée comme stockage principal de la télémétrie des drones.

## Connexions Airflow

Airflow peut utiliser des connexions pour accéder à :

- une base PostgreSQL ;
- un stockage objet ;
- une API ;
- un service externe ;
- un système de fichiers.

Les identifiants et mots de passe ne doivent pas être placés directement dans le code des DAGs.

Ils devront être fournis par :

- des variables d’environnement ;
- des secrets ;
- la configuration Airflow ;
- un gestionnaire de secrets.

## Secrets

Les futurs secrets Airflow peuvent inclure :

```text
AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
DATABASE_URL
API_TOKEN
MQTT_PASSWORD
STORAGE_ACCESS_KEY
```

!!! danger "Aucun secret dans Git"

    Les secrets ne doivent être ajoutés ni dans :

    - les DAGs ;
    - les fichiers Markdown ;
    - les exemples versionnés ;
    - les Dockerfiles ;
    - les valeurs Helm publiques.

## Dépendances

Airflow doit posséder son propre environnement Python.

Il ne doit pas utiliser :

```text
Application/fleet-api/.venv/
```

ni :

```text
Documentation/.venv/
```

Une future installation pourrait utiliser :

```text
Application/airflow/.venv/
```

ou une image Docker dédiée.

## Tests des DAGs

Un DAG doit pouvoir être importé sans erreur.

Les tests peuvent vérifier :

- que le DAG existe ;
- que son identifiant est correct ;
- que les tâches attendues sont présentes ;
- que les dépendances sont correctes ;
- que les paramètres obligatoires sont définis ;
- que les fonctions de transformation sont testables séparément.

Exemple conceptuel :

```python
def test_dag_is_importable(dag_bag):
    dag = dag_bag.get_dag(
        "daily_telemetry_summary"
    )

    assert dag is not None
    assert not dag_bag.import_errors
```

## Séparer orchestration et logique métier

Les DAGs doivent principalement décrire l’enchaînement des tâches.

La logique complexe peut être placée dans des modules Python indépendants.

Exemple :

```text
Application/airflow/
├── dags/
│   └── telemetry_pipeline.py
└── machina_airflow/
    ├── validation.py
    ├── aggregation.py
    └── storage.py
```

Cela facilite :

- les tests unitaires ;
- la réutilisation ;
- la lisibilité des DAGs ;
- la maintenance.

## Idempotence

Une tâche Airflow peut être rejouée.

Elle doit donc éviter de produire des résultats incohérents lorsqu’elle est exécutée plusieurs fois.

Exemples de stratégies :

- utiliser une période comme clé ;
- remplacer une agrégation existante ;
- utiliser une opération d’upsert ;
- enregistrer un identifiant d’exécution ;
- vérifier la présence d’un export ;
- écrire dans un fichier temporaire puis le renommer.

## Dates et périodes

Les tâches doivent traiter une période déterminée par leur contexte d’exécution plutôt que par l’heure courante du serveur.

Exemple conceptuel :

```text
début de la période
fin de la période
```

Cela facilite :

- les rejeux ;
- les tests ;
- les traitements historiques ;
- la reproductibilité.

## Gestion des erreurs

Un futur pipeline devra définir :

- le nombre de tentatives ;
- le délai entre les tentatives ;
- les erreurs temporaires ;
- les erreurs définitives ;
- les notifications ;
- le comportement en cas de données invalides ;
- les résultats partiels.

Une tâche ne doit pas masquer silencieusement une erreur importante.

## Observabilité

Airflow possède sa propre visibilité sur les exécutions, mais il devra également s’intégrer aux pratiques du projet.

Points à surveiller :

- état des DAGs ;
- durée des tâches ;
- taux d’échec ;
- nombre de rejeux ;
- retard de planification ;
- disponibilité de la base de métadonnées ;
- espace disque ;
- volume des logs ;
- disponibilité du stockage de télémétrie.

## Logs

Les logs ne doivent pas contenir :

- de mots de passe ;
- de secrets MQTT ;
- de chaînes de connexion complètes ;
- de tokens ;
- de payloads sensibles non nécessaires.

Les messages peuvent inclure :

- la période traitée ;
- le nombre de lignes lues ;
- le nombre de lignes valides ;
- le nombre d’erreurs ;
- la destination d’un export ;
- la durée du traitement.

## Rétention

Airflow peut produire beaucoup de métadonnées et de logs.

Une future intégration devra prévoir :

- la durée de conservation des logs ;
- le nettoyage des anciennes exécutions ;
- la taille des volumes ;
- la conservation des artefacts ;
- la suppression des fichiers temporaires.

## Docker Compose

Airflow ne doit pas être ajouté immédiatement à :

```text
Application/docker-compose.yml
```

Une expérimentation isolée est préférable dans un premier temps.

Lorsque le fonctionnement sera stabilisé, il faudra décider si Airflow doit :

- rester dans un Compose indépendant ;
- rejoindre le Compose principal ;
- être lancé uniquement à la demande ;
- être déployé dans un cluster distinct.

## Kubernetes

Airflow ne doit pas être ajouté directement au chart :

```text
Application/machina-sandbox/
```

pendant la première expérimentation.

Le chart principal déploie actuellement :

- le broker ;
- Fleet API ;
- le frontend.

Airflow est un ensemble plus lourd et possède un cycle de vie différent.

!!! info "Déploiement séparé"

    Une future intégration Kubernetes pourrait utiliser :

    - un chart Airflow indépendant ;
    - une release Helm indépendante ;
    - un namespace propre ;
    - une application Argo CD propre.

## Namespace possible

Un namespace dédié pourrait être utilisé :

```text
machina-airflow
```

Il permettrait de séparer :

- les pods ;
- les secrets ;
- les volumes ;
- les droits ;
- les releases ;
- les ressources.

Ce choix n’est pas encore officiel.

## Release Helm possible

Une future release pourrait s’appeler :

```text
machina-airflow
```

Elle resterait distincte de :

```text
machina-sandbox
```

Cette séparation permettrait de démarrer ou d’arrêter Airflow sans modifier les composants principaux.

## GitOps

Si Airflow est déployé plus tard avec Argo CD, il pourra disposer de sa propre application GitOps.

Exemple conceptuel :

```text
Application/k8s/argocd/airflow-application.yaml
```

Ce fichier n’existe pas actuellement.

Il devra pointer vers une source de déploiement validée.

## Monitoring

Une future intégration pourra surveiller :

- le scheduler ;
- le webserver ;
- les workers ;
- la base de métadonnées ;
- les DAGs en échec ;
- les tâches en retard ;
- les files d’attente ;
- la durée des traitements.

L’ajout de métriques doit être documenté dans :

```text
operations/monitoring.md
```

## Sécurité

Une installation Airflow expose généralement une interface d’administration.

Elle devra être protégée par :

- une authentification ;
- des droits utilisateurs ;
- un réseau contrôlé ;
- HTTPS dans un environnement exposé ;
- une gestion des secrets ;
- des mises à jour maîtrisées.

!!! danger "Interface d’administration"

    L’interface Airflow ne doit pas être exposée publiquement avec une configuration de démonstration ou des identifiants faibles.

## Ressources

Airflow consomme davantage de ressources qu’un simple script Python.

Une expérimentation devra mesurer :

- CPU ;
- mémoire ;
- stockage ;
- temps de démarrage ;
- taille des images ;
- volume de logs.

Ces mesures permettront de décider s’il est pertinent de le lancer en permanence dans Minikube.

## Limites dans le contexte actuel

L’intégration Airflow dépend encore de plusieurs décisions :

- aucun consommateur backend de télémétrie n’est implémenté ;
- aucun stockage de télémétrie n’est choisi ;
- les contrats MQTT ne sont pas versionnés ;
- les flux GPS et IoT ne sont pas encore séparés ;
- aucun DAG n’existe ;
- aucune stratégie de déploiement n’est définie ;
- aucune base de métadonnées Airflow n’est installée ;
- aucune authentification Airflow n’est configurée.

Airflow ne doit donc pas devenir une dépendance obligatoire à ce stade.

## Progression recommandée

### Phase 1 — stabiliser les données

1. stabiliser le payload de télémétrie ;
2. préciser les unités ;
3. ajouter un numéro de version ;
4. corriger les incohérences de topics ;
5. introduire éventuellement les types de véhicules.

### Phase 2 — ajouter un consommateur

1. créer un consommateur MQTT ;
2. valider les messages ;
3. gérer les reconnexions ;
4. ajouter des tests ;
5. stocker les données.

### Phase 3 — choisir le stockage

1. tester une solution simple ;
2. mesurer le volume ;
3. définir la rétention ;
4. documenter le schéma ;
5. permettre le rejeu.

### Phase 4 — premier DAG Airflow

1. créer un environnement Airflow isolé ;
2. importer un DAG minimal ;
3. lire une période de données ;
4. calculer une agrégation ;
5. enregistrer un résultat ;
6. tester un rejeu.

### Phase 5 — intégration

1. ajouter les tests Airflow à la CI ;
2. documenter les commandes ;
3. ajouter le monitoring ;
4. décider du mode de déploiement ;
5. préparer éventuellement Helm et GitOps.

## Premier prototype minimal

Un prototype raisonnable pourrait se limiter à :

```text
Consommateur MQTT
    |
    v
Fichier JSON Lines
    |
    v
DAG Airflow quotidien
    |
    v
Rapport JSON agrégé
```

Cette architecture permettrait d’expérimenter Airflow sans introduire immédiatement une nouvelle base de données.

## Critères de réussite

Une première expérimentation pourrait être considérée comme réussie si :

- Airflow démarre indépendamment de l’application ;
- un DAG est importé sans erreur ;
- une période de télémétrie peut être lue ;
- les données invalides sont identifiées ;
- une agrégation est produite ;
- le DAG peut être rejoué ;
- les tests passent ;
- aucun secret n’est versionné ;
- le fonctionnement est documenté ;
- l’application principale continue de fonctionner sans Airflow.

## Décision d’intégration

Après le prototype, plusieurs décisions seront possibles.

### Conserver Airflow

Airflow est pertinent si les besoins incluent :

- plusieurs traitements dépendants ;
- de la planification ;
- des rejeux ;
- une supervision des tâches ;
- des traitements historiques ;
- plusieurs sources et destinations.

### Utiliser un outil plus simple

Un script planifié peut suffire si le besoin reste limité à :

- une seule tâche ;
- un faible volume ;
- peu de dépendances ;
- aucun besoin de rejeu complexe ;
- aucune interface de suivi.

Le choix devra dépendre des expériences réalisées plutôt que d’une obligation architecturale.

## État actuel

| Élément                   | État           |
| ------------------------- | -------------- |
| Airflow dans le dépôt     | absent         |
| Service Docker Compose    | absent         |
| Déploiement Kubernetes    | absent         |
| Chart Helm Airflow        | absent         |
| Application Argo CD       | absente        |
| DAGs                      | absents        |
| Stockage de télémétrie    | non défini     |
| Consommateur backend MQTT | non implémenté |
| Cas d’usage               | envisagés      |
| Intégration future        | expérimentale  |

## Pages associées

- [Consommer la télémétrie](telemetry-consumer.md)
- [Contrats de messages](message-contracts.md)
- [Ajouter un service](add-a-service.md)
- [Flux de données](../architecture/data-flow.md)
- [Environnements](../architecture/environments.md)
- [Monitoring](../operations/monitoring.md)
- [Règles de déploiement](../gitops/deployment-rules.md)
