# =============================================================================
# Makefile — co-owned by all 3 teams
#
# Provides a unified command interface so each team doesn't need
# to remember Docker Compose flags or bootstrap scripts.
#
# Usage:
#   make help           — list all targets
#   make up             — start full stack (all teams)
#   make up-infra       — Team 1 only
#   make up-security    — Team 2 only
#   make up-obs         — Team 3 only
#   make bootstrap      — first-time full setup (k3d + everything)
#   make status         — show all service health
#   make logs SVC=jenkins — tail logs for a service
# =============================================================================

.PHONY: help up up-infra up-security up-obs down restart status logs \
        bootstrap k3d-create k3d-delete argocd-install \
        build-agent setup-env clean

# Load .env if it exists
ifneq (,$(wildcard .env))
  include .env
  export
endif

COMPOSE        := docker compose
COMPOSE_INFRA  := docker compose -f docker-compose.infra.yml
COMPOSE_SEC    := docker compose -f docker-compose.security.yml
COMPOSE_OBS    := docker compose -f docker-compose.obs.yml

GREEN  := \033[0;32m
YELLOW := \033[1;33m
CYAN   := \033[0;36m
NC     := \033[0m

##@ General

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\n$(CYAN)DevSecOps Factory — Commands$(NC)\n\n"} \
	  /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } \
	  /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) }' $(MAKEFILE_LIST)

##@ First-time setup

bootstrap: setup-env network-create up k3d-create k3d-configure argocd-install ## Full first-time bootstrap
	@echo ""
	@echo "$(GREEN)Bootstrap complete!$(NC)"
	@make status

setup-env: ## Copy env template if .env doesn't exist
	@if [ ! -f .env ]; then \
	  cp shared/contracts/env-template.env .env; \
	  echo "$(YELLOW).env created from template — edit it with your values$(NC)"; \
	else \
	  echo ".env already exists — skipping"; \
	fi

##@ Docker Compose

network-create: ## Create shared Docker network
	@docker network inspect devsecops >/dev/null 2>&1 || \
	  docker network create --driver bridge --subnet 172.28.0.0/16 devsecops
	@echo "$(GREEN)Network 'devsecops' ready$(NC)"

up: ## Start full stack (all teams)
	$(COMPOSE) up -d --remove-orphans
	@echo "$(GREEN)Full stack started$(NC)"

up-infra: network-create ## [Team 1] Start infrastructure services only
	$(COMPOSE_INFRA) up -d --remove-orphans
	@echo "$(GREEN)Infra services started (Jenkins, Gitea, Registry)$(NC)"

up-security: network-create ## [Team 2] Start security services only
	$(COMPOSE_SEC) up -d --remove-orphans
	@echo "$(GREEN)Security services started (SonarQube, DefectDojo, ZAP)$(NC)"

up-obs: network-create ## [Team 3] Start observability services only
	$(COMPOSE_OBS) up -d --remove-orphans
	@echo "$(GREEN)Observability services started (Prometheus, Grafana, Loki)$(NC)"

down: ## Stop all services
	$(COMPOSE) down

restart: down up ## Restart full stack

status: ## Show health of all services
	@echo ""
	@echo "$(CYAN)── Service Status ─────────────────────────────────$(NC)"
	@docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "$(CYAN)── Access URLs ────────────────────────────────────$(NC)"
	@echo "  Jenkins        http://localhost:8080"
	@echo "  Gitea          http://localhost:3000"
	@echo "  Registry       localhost:5001"
	@echo ""

logs: ## Tail logs (usage: make logs SVC=jenkins)
	docker logs -f $(SVC)

##@ Kubernetes (k3d)

k3d-create: ## Create local k3d cluster (replaces AWS EKS)
	@if k3d cluster list 2>/dev/null | grep -q devsecops; then \
	  echo "k3d cluster 'devsecops' already exists"; \
	else \
	  k3d cluster create --config infrastructure/k3d/cluster.yaml; \
	  echo "$(GREEN)k3d cluster created$(NC)"; \
	fi

k3d-configure: ## Export kubeconfig + install ingress-nginx
	@k3d kubeconfig get devsecops > ~/.kube/devsecops-local.kubeconfig
	@export KUBECONFIG=~/.kube/devsecops-local.kubeconfig && \
	  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update && \
	  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
	    --namespace ingress-nginx --create-namespace \
	    --set controller.hostPort.enabled=true \
	    --set controller.service.type=NodePort \
	    --wait --timeout 3m
	@echo "$(GREEN)ingress-nginx installed on k3d$(NC)"

k3d-delete: ## Delete local k3d cluster
	k3d cluster delete devsecops

##@ Build

build-agent: ## [Linh] Build Jenkins agent image with all security tools
	docker build -t devsecops-agent:latest -f ci/Dockerfile.agent .
	docker tag devsecops-agent:latest localhost:5001/devsecops-agent:latest
	docker push localhost:5001/devsecops-agent:latest

##@ Cleanup

clean: down k3d-delete ## Remove all containers and k3d cluster
	docker volume prune -f
	@echo "$(GREEN)Cleanup complete$(NC)"

clean-volumes: ## Remove all Docker volumes (DATA LOSS)
	@echo "$(YELLOW)WARNING: This will delete all persistent data!$(NC)"
	@read -p "Are you sure? [y/N] " ans && [ "$$ans" = "y" ] && \
	  docker compose down -v && echo "Volumes removed" || echo "Aborted"
