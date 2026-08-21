SHELL := /bin/bash
.DEFAULT_GOAL := help

APPLICATION_DIR ?= Application
DOCUMENTATION_DIR ?= Documentation
SCRIPTS_DIR := $(APPLICATION_DIR)/scripts
MINIKUBE_PROFILE ?= minikube
ARGOCD_PORT ?= 8081
COMPOSE ?= docker compose --project-directory $(APPLICATION_DIR) -f $(APPLICATION_DIR)/docker-compose.yml
HELM_CHART ?= $(APPLICATION_DIR)/machina-sandbox
HELM_RELEASE ?= machina-test
HELM_NAMESPACE ?= machina-helm-test
RENDERED_MANIFEST ?= /tmp/machina-rendered.yaml

CI_CHART ?= Application/machina-sandbox
CI_DEV_VALUES ?= $(CI_CHART)/values-dev.yaml
CI_PROD_VALUES ?= $(CI_CHART)/values-prod.yaml
CI_RENDER_DIR ?= /tmp/machina-ci


DOCS_VENV ?= $(DOCUMENTATION_DIR)/.venv
DOCS_PYTHON ?= $(DOCS_VENV)/bin/python
DOCS_MKDOCS ?= $(DOCS_VENV)/bin/mkdocs
DOCS_CONFIG ?= $(DOCUMENTATION_DIR)/mkdocs.yml
DOCS_REQUIREMENTS ?= $(DOCUMENTATION_DIR)/requirements-docs.txt
DOCS_SITE_DIR ?= $(DOCUMENTATION_DIR)/site
DOCS_HOST ?= 0.0.0.0
DOCS_PORT ?= 8001

# Configuration locale Docker Compose
MACHINA_MQTT_PORT ?= 1883
MACHINA_MQTT_WS_PORT ?= 9001
MACHINA_API_PORT ?= 8000
MACHINA_FRONT_PORT ?= 8085
MACHINA_SHARED_SECRET ?= dev-secret-change-me

# Charge .env lorsqu'il existe
-include $(APPLICATION_DIR)/.env

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
	compose-config compose-up compose-down compose-restart compose-status compose-logs \
    ci-gitops \

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

ci-gitops: ## Valide les rendus Helm DEV et PROD utilisés par GitOps
	@echo "=== Préparation validation GitOps ==="
	@rm -rf $(CI_RENDER_DIR)
	@mkdir -p $(CI_RENDER_DIR)

	@echo
	@echo "=== Helm lint DEV ==="
	@helm lint $(CI_CHART) \
		--strict \
		--values $(CI_DEV_VALUES)

	@echo
	@echo "=== Helm template DEV ==="
	@helm template machina-sandbox $(CI_CHART) \
		--namespace machina-sandbox \
		--values $(CI_DEV_VALUES) \
		> $(CI_RENDER_DIR)/dev.yaml

	@echo
	@echo "=== Kubeconform DEV ==="
	@kubeconform \
		-strict \
		-summary \
		-ignore-missing-schemas \
		$(CI_RENDER_DIR)/dev.yaml

	@echo
	@echo "=== Helm lint PROD ==="
	@helm lint $(CI_CHART) \
		--strict \
		--values $(CI_PROD_VALUES)

	@echo
	@echo "=== Helm template PROD ==="
	@helm template machina-sandbox $(CI_CHART) \
		--namespace machina-sandbox \
		--values $(CI_PROD_VALUES) \
		> $(CI_RENDER_DIR)/prod.yaml

	@echo
	@echo "=== Kubeconform PROD ==="
	@kubeconform \
		-strict \
		-summary \
		-ignore-missing-schemas \
		$(CI_RENDER_DIR)/prod.yaml

	@echo
	@echo "Validation GitOps DEV + PROD réussie."

k8s-connect: ## Connecte le Dev Container au cluster Minikube machina
	@CONNECT_MINIKUBE_STRICT=1 bash .devcontainer/connect-minikube.sh

k8s-status: k8s-connect ## Vérifie la connexion Kubernetes depuis le Dev Container
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
DEVCONT_CHART ?= $(APPLICATION_DIR)/machina-sandbox

DEVCONT_VALUES ?= $(DEVCONT_CHART)/values-dev.yaml

DEVCONT_API_NODEPORT ?= 30800
DEVCONT_FRONT_NODEPORT ?= 32449
DEVCONT_MQTT_NODEPORT ?= 31883
DEVCONT_MQTT_WS_NODEPORT ?= 30901

DEVCONT_HELM_TIMEOUT ?= 5m


DEVCONT_KUBE_CONTEXT ?= machina

DEVCONT_ARGOCD_NAMESPACE ?= argocd
DEVCONT_ARGOCD_VERSION ?= v3.5.1
DEVCONT_ARGOCD_PORT ?= 8080
DEVCONT_ARGOCD_TIMEOUT ?= 180s
DEVCONT_ARGOCD_INSTALL_URL ?= https://raw.githubusercontent.com/argoproj/argo-cd/$(DEVCONT_ARGOCD_VERSION)/manifests/install.yaml
DEVCONT_ARGOCD_APP ?= machina-sandbox-dev

DEVCONT_MONITORING_NAMESPACE ?= monitoring
DEVCONT_MONITORING_RELEASE ?= monitoring
DEVCONT_MONITORING_CHART ?= prometheus-community/kube-prometheus-stack
DEVCONT_MONITORING_VERSION ?= 88.1.5
DEVCONT_MONITORING_VALUES ?= $(APPLICATION_DIR)/k8s/monitoring/prometheus-values.yaml
DEVCONT_MONITORING_TIMEOUT ?= 10m

DEVCONT_DASHBOARD_SCRIPT ?= $(APPLICATION_DIR)/scripts/observability/install-dashboard.sh

DEVCONT_LOKI_RELEASE ?= loki
DEVCONT_LOKI_CHART ?= grafana-community/loki
DEVCONT_LOKI_VERSION ?= 18.7.6
DEVCONT_LOKI_VALUES ?= $(APPLICATION_DIR)/k8s/monitoring/loki-values.yaml

DEVCONT_ALLOY_RELEASE ?= alloy
DEVCONT_ALLOY_CHART ?= grafana/alloy
DEVCONT_ALLOY_VERSION ?= 1.11.1
DEVCONT_ALLOY_VALUES ?= $(APPLICATION_DIR)/k8s/monitoring/alloy-values.yaml



.PHONY: \
        devcont-bootstrap \
        devcont-build-images \
        devcont-load-images \
        devcont-deploy \
        devcont-start \
        devcont-check \
        devcont-status \
        devcont-stop \
        devcont-monitoring-install \
        devcont-monitoring-start \
        devcont-monitoring-check \
        devcont-monitoring-status \
		devcont-dashboard-install \
		devcont-loki-install \
		devcont-loki-check \
		devcont-alloy-install \
		devcont-alloy-check \
		devcont-dashboard-install \
        devcont-observability-check \
        devcont-observability-bootstrap \
		devcont-argocd-install \
		devcont-argocd-check \
        devcont-argocd-status \
		devcont-argocd-bootstrap \
		devcont-argocd-forward \
		devcont-argocd-initial-password \
        devcont-gitops-check \



devcont-bootstrap: devcont-deploy ## Première installation complète depuis le Dev Container


devcont-build-images: ## Construit les images applicatives destinées à Minikube
	echo "=== Construction des images Kubernetes ==="
	docker build --tag fleet-api:latest $(APPLICATION_DIR)/fleet-api
	docker build --tag front:latest $(APPLICATION_DIR)/front
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
	MINIKUBE_IP="$$(docker inspect $(DEVCONT_MINIKUBE_CONTAINER) --format '{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' | head -n 1)"; \
	test -n "$$MINIKUBE_IP" || { echo "ERREUR : IP Minikube introuvable."; exit 1; }; \
	helm upgrade --install $(DEVCONT_RELEASE) $(DEVCONT_CHART) \
		--namespace $(DEVCONT_NAMESPACE) \
		--create-namespace \
		--values $(DEVCONT_VALUES) \
		--set-string fleetApi.env.corsOrigins="http://$$MINIKUBE_IP:$(DEVCONT_FRONT_NODEPORT)" \
		--wait \
		--timeout $(DEVCONT_HELM_TIMEOUT) \
		--rollback-on-failure
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

# ==========================================================
# Dev Container - Monitoring
# ==========================================================

devcont-monitoring-install: k8s-connect ## Installe ou met à jour Prometheus et Grafana dans machina
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
	helm repo update prometheus-community
	helm upgrade --install $(DEVCONT_MONITORING_RELEASE) $(DEVCONT_MONITORING_CHART) --version $(DEVCONT_MONITORING_VERSION) --kube-context $(DEVCONT_KUBE_CONTEXT) --namespace $(DEVCONT_MONITORING_NAMESPACE) --create-namespace --values $(DEVCONT_MONITORING_VALUES) --wait --wait-for-jobs --timeout $(DEVCONT_MONITORING_TIMEOUT) --rollback-on-failure
	$(MAKE) devcont-monitoring-check

devcont-monitoring-check: k8s-connect ## Vérifie la release et les workloads Prometheus/Grafana
	helm --kube-context $(DEVCONT_KUBE_CONTEXT) status $(DEVCONT_MONITORING_RELEASE) --namespace $(DEVCONT_MONITORING_NAMESPACE) >/dev/null
	kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status deployment/monitoring-grafana --namespace $(DEVCONT_MONITORING_NAMESPACE) --timeout=180s
	kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status deployment/monitoring-kube-prometheus-operator --namespace $(DEVCONT_MONITORING_NAMESPACE) --timeout=180s
	kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status deployment/monitoring-kube-state-metrics --namespace $(DEVCONT_MONITORING_NAMESPACE) --timeout=180s
	kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status daemonset/monitoring-prometheus-node-exporter --namespace $(DEVCONT_MONITORING_NAMESPACE) --timeout=180s
	kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status statefulset/prometheus-monitoring-kube-prometheus-prometheus --namespace $(DEVCONT_MONITORING_NAMESPACE) --timeout=180s
	echo "Monitoring Prometheus/Grafana opérationnel."

devcont-monitoring-start: k8s-connect ## Attend le redémarrage du monitoring déjà installé
	helm --kube-context $(DEVCONT_KUBE_CONTEXT) status $(DEVCONT_MONITORING_RELEASE) --namespace $(DEVCONT_MONITORING_NAMESPACE) >/dev/null 2>&1 || { echo "ERREUR : release monitoring absente. Lance d'abord 'make devcont-monitoring-install'."; exit 1; }
	$(MAKE) devcont-monitoring-check

devcont-monitoring-status: k8s-connect ## Affiche l'état du monitoring dans machina
	echo "=== Release monitoring ==="
	helm --kube-context $(DEVCONT_KUBE_CONTEXT) list --namespace $(DEVCONT_MONITORING_NAMESPACE)
	echo
	echo "=== Pods et services ==="
	kubectl --context $(DEVCONT_KUBE_CONTEXT) get pods,services --namespace $(DEVCONT_MONITORING_NAMESPACE)
	echo
	echo "Grafana    : port-forward local 3000 -> monitoring-grafana:80"
	echo "Prometheus : port-forward local 9090 -> monitoring-kube-prometheus-prometheus:9090"

devcont-dashboard-install: k8s-connect ## Provisionne le dashboard Machina Control Sandbox dans Grafana
	KUBE_CONTEXT=$(DEVCONT_KUBE_CONTEXT) MONITORING_NAMESPACE=$(DEVCONT_MONITORING_NAMESPACE) bash $(DEVCONT_DASHBOARD_SCRIPT)

devcont-loki-install: k8s-connect ## Installe ou met à jour Loki dans machina
	helm repo add grafana-community https://grafana-community.github.io/helm-charts --force-update
	helm repo update grafana-community
	helm upgrade --install $(DEVCONT_LOKI_RELEASE) $(DEVCONT_LOKI_CHART) --version $(DEVCONT_LOKI_VERSION) --kube-context $(DEVCONT_KUBE_CONTEXT) --namespace $(DEVCONT_MONITORING_NAMESPACE) --create-namespace --values $(DEVCONT_LOKI_VALUES) --wait --wait-for-jobs --timeout $(DEVCONT_MONITORING_TIMEOUT) --rollback-on-failure
	$(MAKE) devcont-loki-check


devcont-loki-check: k8s-connect ## Vérifie Loki
	helm --kube-context $(DEVCONT_KUBE_CONTEXT) status $(DEVCONT_LOKI_RELEASE) --namespace $(DEVCONT_MONITORING_NAMESPACE) >/dev/null
	kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status statefulset/loki --namespace $(DEVCONT_MONITORING_NAMESPACE) --timeout=180s
	kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status deployment/loki-gateway --namespace $(DEVCONT_MONITORING_NAMESPACE) --timeout=180s
	kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status daemonset/loki-canary --namespace $(DEVCONT_MONITORING_NAMESPACE) --timeout=180s
	echo "Loki opérationnel."

devcont-alloy-install: k8s-connect ## Installe ou met à jour Grafana Alloy dans machina
	helm repo add grafana https://grafana.github.io/helm-charts --force-update
	helm repo update grafana
	helm upgrade --install $(DEVCONT_ALLOY_RELEASE) $(DEVCONT_ALLOY_CHART) --version $(DEVCONT_ALLOY_VERSION) --kube-context $(DEVCONT_KUBE_CONTEXT) --namespace $(DEVCONT_MONITORING_NAMESPACE) --create-namespace --values $(DEVCONT_ALLOY_VALUES) --wait --wait-for-jobs --timeout $(DEVCONT_MONITORING_TIMEOUT) --rollback-on-failure
	$(MAKE) devcont-alloy-check


devcont-alloy-check: k8s-connect ## Vérifie Grafana Alloy
	helm --kube-context $(DEVCONT_KUBE_CONTEXT) status $(DEVCONT_ALLOY_RELEASE) --namespace $(DEVCONT_MONITORING_NAMESPACE) >/dev/null
	kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status deployment/alloy --namespace $(DEVCONT_MONITORING_NAMESPACE) --timeout=180s
	echo "Grafana Alloy opérationnel."

devcont-observability-check: k8s-connect ## Vérifie toute la pile d'observabilité Machina
	echo "=== Vérification de l'observabilité Machina ==="
	helm --kube-context $(DEVCONT_KUBE_CONTEXT) status $(DEVCONT_MONITORING_RELEASE) --namespace $(DEVCONT_MONITORING_NAMESPACE) >/dev/null
	helm --kube-context $(DEVCONT_KUBE_CONTEXT) status $(DEVCONT_LOKI_RELEASE) --namespace $(DEVCONT_MONITORING_NAMESPACE) >/dev/null
	helm --kube-context $(DEVCONT_KUBE_CONTEXT) status $(DEVCONT_ALLOY_RELEASE) --namespace $(DEVCONT_MONITORING_NAMESPACE) >/dev/null
	$(MAKE) devcont-monitoring-check
	$(MAKE) devcont-loki-check
	$(MAKE) devcont-alloy-check
	test "$$(kubectl --context $(DEVCONT_KUBE_CONTEXT) get configmap machina-control-sandbox-dashboard --namespace $(DEVCONT_MONITORING_NAMESPACE) -o jsonpath='{.metadata.labels.grafana_dashboard}')" = "1"
	echo "Dashboard Machina Control Sandbox provisionné."
	echo "Observabilité Machina opérationnelle."

devcont-observability-bootstrap: k8s-connect ## Installe toute l'observabilité Machina
	echo "=== Bootstrap de l'observabilité Machina ==="
	$(MAKE) devcont-loki-install
	$(MAKE) devcont-monitoring-install
	$(MAKE) devcont-alloy-install
	$(MAKE) devcont-dashboard-install
	$(MAKE) devcont-observability-check
	echo "=== Observabilité Machina prête ==="

# ==========================================================
# Dev Container - Argo CD
# ==========================================================

devcont-argocd-install: k8s-connect ## Installe Argo CD dans le cluster machina
	@echo "=== Installation de Argo CD $(DEVCONT_ARGOCD_VERSION) ==="
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) create namespace $(DEVCONT_ARGOCD_NAMESPACE) \
		--dry-run=client \
		-o yaml \
		| kubectl --context $(DEVCONT_KUBE_CONTEXT) apply -f -
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) apply \
		--namespace $(DEVCONT_ARGOCD_NAMESPACE) \
		--server-side \
		--force-conflicts \
		-f $(DEVCONT_ARGOCD_INSTALL_URL)
	@echo "Installation Argo CD appliquée."

devcont-argocd-bootstrap: devcont-argocd-install ## Installe et vérifie Argo CD dans machina
	@$(MAKE) devcont-argocd-check
	@echo "=== Argo CD Machina prêt ==="

devcont-argocd-check: k8s-connect ## Vérifie Argo CD dans le cluster machina
	@echo "=== Vérification de Argo CD ==="
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) get namespace $(DEVCONT_ARGOCD_NAMESPACE) >/dev/null
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status deployment/argocd-applicationset-controller --namespace $(DEVCONT_ARGOCD_NAMESPACE) --timeout=$(DEVCONT_ARGOCD_TIMEOUT)
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status deployment/argocd-dex-server --namespace $(DEVCONT_ARGOCD_NAMESPACE) --timeout=$(DEVCONT_ARGOCD_TIMEOUT)
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status deployment/argocd-notifications-controller --namespace $(DEVCONT_ARGOCD_NAMESPACE) --timeout=$(DEVCONT_ARGOCD_TIMEOUT)
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status deployment/argocd-redis --namespace $(DEVCONT_ARGOCD_NAMESPACE) --timeout=$(DEVCONT_ARGOCD_TIMEOUT)
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status deployment/argocd-repo-server --namespace $(DEVCONT_ARGOCD_NAMESPACE) --timeout=$(DEVCONT_ARGOCD_TIMEOUT)
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status deployment/argocd-server --namespace $(DEVCONT_ARGOCD_NAMESPACE) --timeout=$(DEVCONT_ARGOCD_TIMEOUT)
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) rollout status statefulset/argocd-application-controller --namespace $(DEVCONT_ARGOCD_NAMESPACE) --timeout=$(DEVCONT_ARGOCD_TIMEOUT)
	@echo "Argo CD opérationnel."

devcont-argocd-status: k8s-connect ## Affiche l'état de Argo CD dans machina
	@echo "=== Argo CD ==="
	@echo "Version cible : $(DEVCONT_ARGOCD_VERSION)"
	@echo
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) get pods,services --namespace $(DEVCONT_ARGOCD_NAMESPACE)
	@echo
	@echo "=== Applications Argo CD ==="
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) get applications.argoproj.io --namespace $(DEVCONT_ARGOCD_NAMESPACE)
	@echo
	@echo "Interface : https://localhost:$(DEVCONT_ARGOCD_PORT) via port-forward"

devcont-argocd-forward: k8s-connect ## Ouvre un port-forward local vers l'interface Argo CD
	@echo "=== Interface Argo CD ==="
	@echo "URL : https://localhost:$(DEVCONT_ARGOCD_PORT)"
	@echo "Arrêter le port-forward avec Ctrl+C."
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) \
		--namespace $(DEVCONT_ARGOCD_NAMESPACE) \
		port-forward svc/argocd-server $(DEVCONT_ARGOCD_PORT):443

devcont-argocd-initial-password: k8s-connect ## Prépare le mot de passe initial Argo CD local
	@echo "=== Mot de passe initial Argo CD ==="
	@echo "Le mot de passe sera enregistré localement dans /tmp/argocd-initial-password."
	@echo "Ne pas versionner ni partager ce fichier."
	@umask 077; \
		argocd admin initial-password \
		--namespace $(DEVCONT_ARGOCD_NAMESPACE) \
		--kube-context $(DEVCONT_KUBE_CONTEXT) \
		| head -n 1 \
		> /tmp/argocd-initial-password
	@echo "Utilisateur : admin"
	@echo "Mot de passe : /tmp/argocd-initial-password"

devcont-gitops-check: k8s-connect ## Vérifie l'état GitOps de Machina
	@echo "=== Vérification GitOps Machina ==="
	@SYNC_STATUS="$$(kubectl --context $(DEVCONT_KUBE_CONTEXT) \
		--namespace $(DEVCONT_ARGOCD_NAMESPACE) \
		get application $(DEVCONT_ARGOCD_APP) \
		-o jsonpath='{.status.sync.status}')"; \
	HEALTH_STATUS="$$(kubectl --context $(DEVCONT_KUBE_CONTEXT) \
		--namespace $(DEVCONT_ARGOCD_NAMESPACE) \
		get application $(DEVCONT_ARGOCD_APP) \
		-o jsonpath='{.status.health.status}')"; \
	echo "Sync   : $$SYNC_STATUS"; \
	echo "Health : $$HEALTH_STATUS"; \
	test "$$SYNC_STATUS" = "Synced" || { echo "ERREUR : application Argo CD non synchronisée."; exit 1; }; \
	test "$$HEALTH_STATUS" = "Healthy" || { echo "ERREUR : application Argo CD non saine."; exit 1; }
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) \
		--namespace $(DEVCONT_NAMESPACE) \
		rollout status deployment/broker --timeout=120s
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) \
		--namespace $(DEVCONT_NAMESPACE) \
		rollout status deployment/fleet-api --timeout=120s
	@kubectl --context $(DEVCONT_KUBE_CONTEXT) \
		--namespace $(DEVCONT_NAMESPACE) \
		rollout status deployment/front --timeout=120s
	@echo "GitOps Machina opérationnel."

# === Host Minikube lifecycle ===

HOST_TOOL ?= tools/host/machina-host

.PHONY: host-bootstrap host-check host-start host-status host-stop host-delete

host-bootstrap: ensure-local ## Installe Minikube si nécessaire et démarre le cluster hôte
	@bash $(HOST_TOOL) bootstrap

host-check: ensure-local ## Vérifie Docker, Minikube et le profil Kubernetes hôte
	@bash $(HOST_TOOL) check

host-start: ensure-local ## Démarre le profil Minikube hôte
	@bash $(HOST_TOOL) start

host-status: ensure-local ## Affiche l'état du profil Minikube hôte
	@bash $(HOST_TOOL) status

host-stop: ensure-local ## Arrête le profil Minikube hôte sans le supprimer
	@bash $(HOST_TOOL) stop

host-delete: ensure-local ## Supprime le profil Minikube hôte après confirmation
	@bash $(HOST_TOOL) delete
# ==========================================================
# Documentation MkDocs
# ==========================================================

.PHONY: \
        docs-install \
        docs-ensure \
        docs-check \
        docs-build \
        docs-serve \
        docs-clean

docs-install: ## Crée l'environnement virtuel et installe MkDocs
	@echo "=== Installation de la documentation ==="
	@test -f "$(DOCS_REQUIREMENTS)" || { \
		echo "ERREUR : fichier absent : $(DOCS_REQUIREMENTS)"; \
		exit 1; \
	}
	@python3 -m venv "$(DOCS_VENV)"
	@"$(DOCS_PYTHON)" -m pip install \
		--disable-pip-version-check \
		--no-input \
		-r "$(DOCS_REQUIREMENTS)"
	@"$(DOCS_PYTHON)" -m pip check
	@"$(DOCS_MKDOCS)" --version

docs-ensure:
	@test -x "$(DOCS_MKDOCS)" || { \
		echo "ERREUR : MkDocs n'est pas installé."; \
		echo "Exécute d'abord : make docs-install"; \
		exit 1; \
	}

docs-check: docs-ensure ## Valide strictement la configuration et les pages MkDocs
	@echo "=== Validation stricte de la documentation ==="
	@"$(DOCS_MKDOCS)" build \
		--config-file "$(DOCS_CONFIG)" \
		--strict \
		--clean

docs-build: docs-ensure ## Génère le site MkDocs dans Documentation/site
	@echo "=== Construction de la documentation ==="
	@"$(DOCS_MKDOCS)" build \
		--config-file "$(DOCS_CONFIG)" \
		--clean
	@echo "Site généré dans : $(DOCS_SITE_DIR)"

docs-serve: docs-ensure ## Sert MkDocs localement sur le port 8001
	@echo "=== Serveur de documentation ==="
	@echo "URL : http://localhost:$(DOCS_PORT)"
	@"$(DOCS_MKDOCS)" serve \
		--config-file "$(DOCS_CONFIG)" \
		--dev-addr "$(DOCS_HOST):$(DOCS_PORT)"

docs-clean: ## Supprime uniquement le site MkDocs généré
	@rm -rf "$(DOCS_SITE_DIR)"
	@echo "Site généré supprimé : $(DOCS_SITE_DIR)"
