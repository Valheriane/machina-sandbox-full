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
