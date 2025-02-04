ifneq ($(shell which docker-compose 2>/dev/null),)
    DOCKER_COMPOSE := docker-compose
else
    DOCKER_COMPOSE := docker compose
endif

install:
	$(DOCKER_COMPOSE) up -d

remove:
	@chmod +x confirm_remove.sh
	@./confirm_remove.sh

start:
	$(DOCKER_COMPOSE) start
startAndBuild: 
	$(DOCKER_COMPOSE) up -d --build

stop:
	$(DOCKER_COMPOSE) stop

update:
	# Calls the LLM update script
	chmod +x update_ollama_models.sh
	@./update_ollama_models.sh
	@git pull
	$(DOCKER_COMPOSE) down
	# Make sure the ollama-webui container is stopped before rebuilding
	@docker stop open-webui || true
	$(DOCKER_COMPOSE) up --build -d
	$(DOCKER_COMPOSE) start

# Development commands
.PHONY: dev-build dev-up dev-down dev-logs dev-frontend-build

dev-build:
	$(DOCKER_COMPOSE) -f docker-compose.dev.yaml build

dev-up: dev-network
	$(DOCKER_COMPOSE) -f docker-compose.dev.yaml up -d

dev-down:
	$(DOCKER_COMPOSE) -f docker-compose.dev.yaml down

dev-logs:
	$(DOCKER_COMPOSE) -f docker-compose.dev.yaml logs -f

dev-network:
	docker network inspect webui-dev-network >/dev/null 2>&1 || \
	docker network create webui-dev-network --subnet=172.20.0.0/16

# Production custom build commands
.PHONY: custom-build custom-push custom-deploy

CUSTOM_REGISTRY ?= your-registry  # e.g., docker.io/username
CUSTOM_TAG ?= latest

custom-build:
	docker build -t $(CUSTOM_REGISTRY)/open-webui:$(CUSTOM_TAG) .

custom-push:
	docker push $(CUSTOM_REGISTRY)/open-webui:$(CUSTOM_TAG)

custom-deploy: prod-network
	$(DOCKER_COMPOSE) -f docker-compose.yaml \
		-f docker-compose.prod.yaml \
		up -d

prod-network:
	docker network create webui-prod-network --subnet=172.21.0.0/16 || true

# Production build specifically for Intel/AMD64
prod-build:
	docker build \
		--platform linux/amd64 \
		-t local/open-webui:prod .

# Deploy using locally built image
prod-up: prod-network
	CUSTOM_REGISTRY=local CUSTOM_TAG=prod docker compose -f docker-compose.prod.yaml up -d

# Helper to clean all
.PHONY: dev-clean-all
dev-clean-all: dev-down clean-networks
	docker system prune -f

clean-networks:
	docker network inspect webui-dev-network >/dev/null 2>&1 && \
	docker network rm webui-dev-network || true
	docker network inspect webui-prod-network >/dev/null 2>&1 && \
	docker network rm webui-prod-network || true

