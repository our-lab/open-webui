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
.PHONY: dev-build dev-up dev-down dev-logs dev-network clean-networks clean-all

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

# Production commands
.PHONY: prod-build prod-up prod-down prod-logs prod-network

prod-build:
	$(DOCKER_COMPOSE) -f docker-compose.prod.yaml build

prod-up: prod-network
	$(DOCKER_COMPOSE) -f docker-compose.prod.yaml up -d

prod-down:
	$(DOCKER_COMPOSE) -f docker-compose.prod.yaml down

prod-logs:
	$(DOCKER_COMPOSE) -f docker-compose.prod.yaml logs -f

prod-network:
	docker network inspect webui-prod-network >/dev/null 2>&1 || \
	docker network create webui-prod-network --subnet=172.21.0.0/16

# Cleanup commands
clean-dev: dev-down
	docker network inspect webui-dev-network >/dev/null 2>&1 && \
	docker network rm webui-dev-network || true
	docker volume rm open-webui-dev || true
	docker system prune -f

clean-prod: prod-down
	docker network inspect webui-prod-network >/dev/null 2>&1 && \
	docker network rm webui-prod-network || true
	docker volume rm open-webui-prod || true
	docker system prune -f

# Keep clean-all for convenience
clean-all: clean-dev clean-prod

