SHELL := /bin/bash
.DEFAULT_GOAL := help

SCRIPTS_DIR := scripts
MINIKUBE_PROFILE ?= minikube
ARGOCD_PORT ?= 8081
COMPOSE ?= docker compose
HELM_CHART ?= ./machina-sandbox
HELM_RELEASE ?= machina-test
HELM_NAMESPACE ?= machina-helm-test
RENDERED_MANIFEST ?= /tmp/machina-rendered.yaml

# Configuration locale Docker Compose
MACHINA_MQTT_PORT ?= 1883
MACHINA_MQTT_WS_PORT ?= 9001
MACHINA_API_PORT ?= 8000
MACHINA_FRONT_PORT ?= 8085
MACHINA_SHARED_SECRET ?= dev-secret-change-me

# Charge .env lorsqu'il existe
-include .env

export MACHINA_MQTT_PORT
export MACHINA_MQTT_WS_PORT
export MACHINA_API_PORT
export MACHINA_FRONT_PORT
export MACHINA_SHARED_SECRET


.PHONY: \
	help permissions versions ensure-local \
	dev-install validate-k8s \
	k8s-connect k8s-status \
	restart start check status \
	check-monitoring check-prometheus check-loki check-argocd \
	open-grafana open-argocd \
	minikube-start minikube-stop minikube-status \
	pods namespaces releases \
	compose-config compose-up compose-down compose-restart compose-status compose-logs

help: ## Affiche la liste des commandes disponibles
	@echo
	@echo "MachinaControl - commandes disponibles"
	@echo "======================================"
	@awk 'BEGIN {FS = ":.*## "; printf "\n"} /^[a-zA-Z0-9_.-]+:.*## / {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo
	@echo "Exemples :"
	@echo "  make restart"
	@echo "  make check"
	@echo "  make open-argocd ARGOCD_PORT=8090"
	@echo "  make compose-up"
	@echo

permissions: ## Rend les scripts Bash exécutables
	@chmod +x $(SCRIPTS_DIR)/*.sh
	@echo "Scripts rendus exécutables."

versions: ## Affiche les versions des principaux outils
	@echo "=== Outils disponibles ==="
	@for cmd in git docker kubectl helm minikube python3 node npm; do \
		if command -v $$cmd >/dev/null 2>&1; then \
			printf "%-12s : " "$$cmd"; \
			case "$$cmd" in \
				docker) docker --version ;; \
				kubectl) kubectl version --client ;; \
				helm) helm version --short ;; \
				minikube) minikube version --short ;; \
				python3) python3 --version ;; \
				node) node --version ;; \
				npm) npm --version ;; \
				git) git --version ;; \
			esac; \
		else \
			printf "%-12s : absent\n" "$$cmd"; \
		fi; \
	done

ensure-local:
	@if [[ -f /.dockerenv || -n "$${REMOTE_CONTAINERS:-}" ]]; then \
		echo "Cette commande pilote le Minikube de la machine hôte."; \
		echo "Quitte le Dev Container puis relance-la depuis le terminal local."; \
		exit 1; \
	fi

restart: ensure-local permissions ## Démarre Minikube et relance/vérifie tout l'environnement
	@$(SCRIPTS_DIR)/restart-project.sh

start: restart ## Alias de make restart

check: ensure-local permissions ## Vérifie l'ensemble du projet, Kubernetes, Helm et Docker
	@$(SCRIPTS_DIR)/check-project.sh

status: check ## Alias de make check

check-monitoring: ensure-local permissions ## Vérifie Grafana, Prometheus, Loki et les releases Helm
	@$(SCRIPTS_DIR)/check-monitoring.sh

check-prometheus: ensure-local permissions ## Vérifie Prometheus et son endpoint de readiness
	@$(SCRIPTS_DIR)/check-prometheus.sh

check-loki: ensure-local permissions ## Vérifie Loki et son endpoint de readiness
	@$(SCRIPTS_DIR)/check-loki.sh

check-argocd: ensure-local permissions ## Vérifie Argo CD
	@$(SCRIPTS_DIR)/check-argocd.sh

open-grafana: ensure-local permissions ## Ouvre le port-forward Grafana sur localhost:3000
	@$(SCRIPTS_DIR)/open-grafana.sh

open-argocd: ensure-local permissions ## Ouvre Argo CD ; surcharge possible avec ARGOCD_PORT=8090
	@$(SCRIPTS_DIR)/open-argocd.sh $(ARGOCD_PORT)

minikube-start: ensure-local ## Démarre le profil Minikube existant sans le supprimer
	@minikube start -p $(MINIKUBE_PROFILE)
	@minikube update-context -p $(MINIKUBE_PROFILE)

minikube-stop: ensure-local ## Arrête Minikube sans supprimer le cluster
	@minikube stop -p $(MINIKUBE_PROFILE)

minikube-status: ensure-local ## Affiche l'état du profil Minikube
	@minikube status -p $(MINIKUBE_PROFILE)

pods: ensure-local ## Affiche tous les pods Kubernetes
	@kubectl get pods -A -o wide

namespaces: ensure-local ## Affiche les namespaces Kubernetes
	@kubectl get namespaces

releases: ensure-local ## Affiche toutes les releases Helm
	@helm list -A

compose-config: ## Valide la configuration Docker Compose sans rien démarrer
	@echo "=== Validation Docker Compose ==="
	@$(COMPOSE) config --quiet
	@echo "Configuration Docker Compose valide."
	@echo
	@echo "Chemin hôte utilisé : $${HOST_PROJECT_PATH:-répertoire local}"
	@echo "MQTT     : localhost:$(MACHINA_MQTT_PORT)"
	@echo "WebSocket: localhost:$(MACHINA_MQTT_WS_PORT)"
	@echo "API      : http://localhost:$(MACHINA_API_PORT)"
	@echo "Frontend : http://localhost:$(MACHINA_FRONT_PORT)"

compose-up: compose-config ## Construit et démarre broker, fleet-api et front avec Docker Compose
	@$(COMPOSE) up -d --build

compose-down: ## Arrête Docker Compose sans supprimer les volumes
	@$(COMPOSE) down

compose-restart: ## Redémarre les services Docker Compose
	@$(COMPOSE) restart

compose-status: ## Affiche l'état et les ports des services Docker Compose
	@$(COMPOSE) ps
	@echo
	@echo "API      : http://localhost:$(MACHINA_API_PORT)"
	@echo "Frontend : http://localhost:$(MACHINA_FRONT_PORT)"

compose-logs: ## Suit les logs Docker Compose
	@$(COMPOSE) logs -f --tail=100

dev-install: ## Installe les dépendances du Dev Container
	@bash .devcontainer/post-create.sh

validate-k8s: ## Valide le chart Helm et les manifests Kubernetes hors ligne
	@echo "=== Vérification du chart Helm ==="
	@helm lint $(HELM_CHART)
	@echo
	@echo "=== Génération des manifests ==="
	@helm template $(HELM_RELEASE) $(HELM_CHART) \
		--namespace $(HELM_NAMESPACE) \
		> $(RENDERED_MANIFEST)
	@echo "Manifest généré : $(RENDERED_MANIFEST)"
	@echo
	@echo "=== Validation Kubeconform ==="
	@kubeconform \
		-strict \
		-summary \
		-ignore-missing-schemas \
		$(RENDERED_MANIFEST)

k8s-connect: ## Connecte le Dev Container au cluster Minikube machina
	@CONNECT_MINIKUBE_STRICT=1 bash .devcontainer/connect-minikube.sh

k8s-status: ## Vérifie la connexion Kubernetes depuis le Dev Container
	@echo "=== Contexte Kubernetes ==="
	@kubectl config current-context
	@echo
	@echo "=== Nœuds ==="
	@kubectl get nodes -o wide
	@echo
	@echo "=== Pods ==="
	@kubectl get pods -A
	@echo
	@echo "=== Releases Helm ==="
	@helm list -A

# ==========================================================
# Dev Container + Minikube (profil machina)
# ==========================================================

DEVCONT_MINIKUBE_CONTAINER ?= machina
DEVCONT_NAMESPACE ?= machina-sandbox
DEVCONT_RELEASE ?= machina-sandbox
DEVCONT_CHART ?= ./machina-sandbox

DEVCONT_API_NODEPORT ?= 30800
DEVCONT_FRONT_NODEPORT ?= 32449
DEVCONT_MQTT_NODEPORT ?= 31883
DEVCONT_MQTT_WS_NODEPORT ?= 30901

DEVCONT_HELM_TIMEOUT ?= 5m


.PHONY: \
	devcont-bootstrap \
	devcont-build-images \
	devcont-load-images \
	devcont-deploy \
	devcont-start \
	devcont-check \
	devcont-status \
	devcont-stop


devcont-bootstrap: devcont-deploy ## Première installation complète depuis le Dev Container


devcont-build-images: ## Construit les images applicatives destinées à Minikube
	echo "=== Construction des images Kubernetes ==="
	docker build --tag fleet-api:latest ./fleet-api
	docker build --tag front:latest ./front
	docker image inspect eclipse-mosquitto:2 >/dev/null 2>&1 || docker pull eclipse-mosquitto:2


devcont-load-images: k8s-connect ## Charge les images locales dans le nœud Minikube
	echo "=== Chargement des images dans Minikube ==="
	test "$$(docker inspect --format '{{.State.Running}}' $(DEVCONT_MINIKUBE_CONTAINER) 2>/dev/null)" = "true" || { echo "ERREUR : le conteneur Minikube '$(DEVCONT_MINIKUBE_CONTAINER)' n'est pas démarré."; exit 1; }
	docker save fleet-api:latest front:latest eclipse-mosquitto:2 | docker exec -i $(DEVCONT_MINIKUBE_CONTAINER) docker load
	docker exec $(DEVCONT_MINIKUBE_CONTAINER) docker image inspect fleet-api:latest front:latest eclipse-mosquitto:2 >/dev/null
	echo "Images chargées dans Minikube."


devcont-deploy: k8s-connect ## Construit, charge et déploie le projet avec Helm
	$(MAKE) validate-k8s
	$(MAKE) devcont-build-images
	$(MAKE) devcont-load-images
	MINIKUBE_IP="$$(docker inspect $(DEVCONT_MINIKUBE_CONTAINER) --format '{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' | head -n 1)"; test -n "$$MINIKUBE_IP" || { echo "ERREUR : IP Minikube introuvable."; exit 1; }; helm upgrade --install $(DEVCONT_RELEASE) $(DEVCONT_CHART) --namespace $(DEVCONT_NAMESPACE) --create-namespace --set-string fleetApi.env.corsOrigins="http://$$MINIKUBE_IP:$(DEVCONT_FRONT_NODEPORT)" --wait --timeout $(DEVCONT_HELM_TIMEOUT) --rollback-on-failure
	kubectl rollout restart deployment/fleet-api deployment/front --namespace $(DEVCONT_NAMESPACE)
	kubectl rollout status deployment/broker --namespace $(DEVCONT_NAMESPACE) --timeout=120s
	kubectl rollout status deployment/fleet-api --namespace $(DEVCONT_NAMESPACE) --timeout=120s
	kubectl rollout status deployment/front --namespace $(DEVCONT_NAMESPACE) --timeout=120s
	$(MAKE) devcont-check


devcont-start: k8s-connect ## Redémarre une release installée sans reconstruire les images
	helm status $(DEVCONT_RELEASE) --namespace $(DEVCONT_NAMESPACE) >/dev/null 2>&1 || { echo "ERREUR : release absente. Lance d'abord 'make devcont-bootstrap'."; exit 1; }
	echo "=== Démarrage du broker ==="
	kubectl scale deployment/broker --namespace $(DEVCONT_NAMESPACE) --replicas=1
	kubectl rollout status deployment/broker --namespace $(DEVCONT_NAMESPACE) --timeout=120s
	echo "=== Démarrage de l'API et du front ==="
	kubectl scale deployment/fleet-api --namespace $(DEVCONT_NAMESPACE) --replicas=1
	kubectl scale deployment/front --namespace $(DEVCONT_NAMESPACE) --replicas=1
	kubectl rollout status deployment/fleet-api --namespace $(DEVCONT_NAMESPACE) --timeout=120s
	kubectl rollout status deployment/front --namespace $(DEVCONT_NAMESPACE) --timeout=120s
	$(MAKE) devcont-check


devcont-check: k8s-connect ## Vérifie Helm, les pods, l'API, le front et MQTT WebSocket
	echo "=== Vérification du déploiement Dev Container ==="
	helm status $(DEVCONT_RELEASE) --namespace $(DEVCONT_NAMESPACE) >/dev/null
	kubectl rollout status deployment/broker --namespace $(DEVCONT_NAMESPACE) --timeout=120s
	kubectl rollout status deployment/fleet-api --namespace $(DEVCONT_NAMESPACE) --timeout=120s
	kubectl rollout status deployment/front --namespace $(DEVCONT_NAMESPACE) --timeout=120s
	MINIKUBE_IP="$$(docker inspect $(DEVCONT_MINIKUBE_CONTAINER) --format '{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' | head -n 1)"; test -n "$$MINIKUBE_IP" || { echo "ERREUR : IP Minikube introuvable."; exit 1; }; echo "API :"; curl --fail --silent --show-error --max-time 15 "http://$$MINIKUBE_IP:$(DEVCONT_API_NODEPORT)/ready"; echo; curl --fail --silent --show-error --head --max-time 15 "http://$$MINIKUBE_IP:$(DEVCONT_FRONT_NODEPORT)/" >/dev/null; timeout 5 bash -c "</dev/tcp/$$MINIKUBE_IP/$(DEVCONT_MQTT_WS_NODEPORT)"; echo "Front et MQTT WebSocket accessibles."; echo "Interface : http://$$MINIKUBE_IP:$(DEVCONT_FRONT_NODEPORT)"


devcont-status: k8s-connect ## Affiche l'état et les URL du déploiement Dev Container
	echo "=== Release Helm ==="
	helm list --namespace $(DEVCONT_NAMESPACE)
	echo
	echo "=== Déploiements, pods et services ==="
	kubectl get deployments,pods,services --namespace $(DEVCONT_NAMESPACE)
	echo
	MINIKUBE_IP="$$(docker inspect $(DEVCONT_MINIKUBE_CONTAINER) --format '{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' | head -n 1)"; echo "Front : http://$$MINIKUBE_IP:$(DEVCONT_FRONT_NODEPORT)"; echo "API   : http://$$MINIKUBE_IP:$(DEVCONT_API_NODEPORT)"; echo "MQTT  : ws://$$MINIKUBE_IP:$(DEVCONT_MQTT_WS_NODEPORT)"


devcont-stop: k8s-connect ## Arrête l'application sans supprimer Helm ni Minikube
	helm status $(DEVCONT_RELEASE) --namespace $(DEVCONT_NAMESPACE) >/dev/null 2>&1 || { echo "ERREUR : release absente."; exit 1; }
	echo "=== Arrêt de l'API et du front ==="
	kubectl scale deployment/fleet-api --namespace $(DEVCONT_NAMESPACE) --replicas=0
	kubectl scale deployment/front --namespace $(DEVCONT_NAMESPACE) --replicas=0
	echo "=== Arrêt du broker ==="
	kubectl scale deployment/broker --namespace $(DEVCONT_NAMESPACE) --replicas=0
	kubectl get deployments --namespace $(DEVCONT_NAMESPACE)
