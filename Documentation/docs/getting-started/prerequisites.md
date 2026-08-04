# Prérequis

Cette page présente les outils nécessaires sur la machine hôte avant d’utiliser **Machina Sandbox Full**.

Le parcours actuellement validé repose sur :

- une machine hôte Linux ;
- Git ;
- Docker ;
- Visual Studio Code ;
- l’extension Dev Containers ;
- un Dev Container ;
- un cluster Minikube exécuté sur l’hôte.

!!! info "Deux environnements distincts"

    Les outils nécessaires sur la machine hôte ne sont pas les mêmes que ceux installés dans le Dev Container.

    Le moteur Docker et le cluster Minikube fonctionnent sur l’hôte Linux.

    Les outils de développement, comme Python, Node.js, `kubectl`, Helm et kubeconform, sont fournis dans le Dev Container.

## Prérequis sur l’hôte Linux

### Git

Git est nécessaire pour :

- cloner le dépôt ;
- créer et utiliser les branches ;
- enregistrer les modifications ;
- envoyer les commits vers le dépôt distant.

Vérification :

```bash
git --version
```

Une version de Git doit être affichée.

## Docker

Docker est utilisé pour :

- exécuter les services avec Docker Compose ;
- construire les images applicatives ;
- exécuter Minikube avec le pilote Docker ;
- fournir le moteur Docker au Dev Container.

Vérification :

```bash
docker --version
docker info
```

La commande `docker info` doit fonctionner sans erreur de permission.

!!! warning "Docker doit fonctionner avant d’ouvrir le Dev Container"

    Le Dev Container utilise le moteur Docker de la machine hôte.

    Si Docker n’est pas démarré ou si l’utilisateur courant ne peut pas accéder au moteur Docker, les commandes Docker, Compose et Minikube ne fonctionneront pas correctement.

## Docker Compose

Docker Compose est utilisé pour lancer l’application sans Kubernetes.

Vérification :

```bash
docker compose version
```

Le projet utilise la commande moderne :

```text
docker compose
```

et non l’ancienne commande séparée `docker-compose`.

## Visual Studio Code

Visual Studio Code est utilisé pour ouvrir le dépôt et démarrer l’environnement de développement conteneurisé.

Vérification :

```bash
code --version
```

Cette commande est facultative si Visual Studio Code est lancé depuis l’interface graphique.

## Extension Dev Containers

L’extension **Dev Containers** de Visual Studio Code doit être installée.

Elle permet :

- d’ouvrir le dépôt dans son environnement conteneurisé ;
- d’installer automatiquement les outils de développement ;
- d’utiliser les dépendances du projet sans les installer directement sur l’hôte ;
- de conserver un environnement reproductible entre les machines.

Dans Visual Studio Code :

1. ouvrir la vue **Extensions** ;
2. rechercher `Dev Containers` ;
3. installer l’extension publiée par Microsoft.

## Make

Le projet utilise un `Makefile` pour regrouper les commandes courantes.

Vérification :

```bash
make --version
```

Les commandes disponibles peuvent ensuite être affichées avec :

```bash
make help
```

## curl

`curl` est utilisé par plusieurs scripts de vérification, notamment pour tester les endpoints HTTP.

Vérification :

```bash
curl --version
```

## Minikube

Minikube exécute le cluster Kubernetes local utilisé par le projet.

Le profil attendu s’appelle :

```text
machina
```

Le projet fournit un outil hôte dans :

```text
tools/host/machina-host
```

Il peut vérifier l’installation de Minikube et démarrer le profil attendu.

Depuis le terminal Linux hôte :

```bash
make host-check
```

Si Minikube n’est pas installé, la commande suivante peut préparer l’environnement :

```bash
make host-bootstrap
```

L’installation automatique prévue par le projet place Minikube dans :

```text
~/.local/bin/minikube
```

lorsqu’aucune installation existante n’est détectée.

!!! warning "Commandes réservées à l’hôte"

    Les commandes `make host-*` administrent Docker et Minikube sur la machine hôte.

    Elles ne doivent pas être lancées depuis le Dev Container.

## Ressources conseillées

Les besoins exacts dépendent du nombre de services exécutés simultanément.

Pour utiliser confortablement Docker, Minikube, Helm et l’application, il est conseillé de disposer de :

| Ressource           |                Recommandation indicative |
| ------------------- | ---------------------------------------: |
| Processeur          |                      4 cœurs disponibles |
| Mémoire vive        |                             8 Go ou plus |
| Espace disque libre |                            10 Go ou plus |
| Réseau              | accès Internet pendant les installations |

Ces valeurs sont des recommandations de confort et non des limites techniques strictes.

## Outils installés dans le Dev Container

Le Dev Container est basé sur Ubuntu 24.04.

Il fournit notamment :

| Outil          | Utilisation                                   |
| -------------- | --------------------------------------------- |
| Python 3.11    | Fleet API, simulateur et outils Python        |
| Node.js 20     | développement du frontend                     |
| npm            | installation des dépendances frontend         |
| Docker CLI     | communication avec le moteur Docker de l’hôte |
| Docker Compose | exécution locale des services                 |
| kubectl        | administration du cluster Kubernetes          |
| Helm           | validation et déploiement du chart            |
| kubeconform    | validation des ressources Kubernetes          |

Ces outils n’ont pas besoin d’être installés séparément sur l’hôte pour travailler dans le Dev Container.

!!! note "Docker-outside-of-Docker"

    Le Dev Container n’exécute pas son propre moteur Docker.

    Il utilise le moteur Docker déjà présent sur la machine hôte grâce au mécanisme Docker-outside-of-Docker.

## Dépendances applicatives

Lors de la création du Dev Container, la commande suivante est exécutée automatiquement :

```bash
make dev-install
```

Elle prépare notamment :

- l’environnement virtuel de Fleet API ;
- l’environnement virtuel du simulateur de drones ;
- les dépendances Node.js du frontend ;
- les répertoires Kubernetes utilisés dans le Dev Container.

Les environnements virtuels applicatifs sont indépendants de l’environnement utilisé par MkDocs.

## Dépendances de la documentation

La documentation utilise son propre environnement Python :

```text
Documentation/.venv/
```

Les dépendances sont déclarées dans :

```text
Documentation/requirements-docs.txt
```

Pour installer ou mettre à jour MkDocs :

```bash
make docs-install
```

Pour vérifier l’installation :

```bash
Documentation/.venv/bin/mkdocs --version
```

## Vérification rapide de l’hôte

Depuis le terminal Linux hôte :

```bash
git --version
docker --version
docker compose version
make --version
curl --version
```

Puis vérifier l’environnement Machina :

```bash
make host-check
```

## Étape suivante

Une fois les prérequis validés, consulte le parcours correspondant à ton besoin :

- [Dev Container et Minikube](devcontainer-minikube.md)
- [Docker Compose local](local-docker.md)
