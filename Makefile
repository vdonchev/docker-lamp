.PHONY: check-env status init up up-pma up-redis up-mailpit up-all build build-no-cache switch-php switch-db \
	restart restart-all down logs logs-web logs-php logs-db logs-pma logs-mailpit logs-redis clean-log \
	cli-db cert shell shell-db fix-perms help

.DEFAULT_GOAL := help

ALL_PROFILES := with-redis,with-pma,with-mailpit

# Internal target: checks if .env exists
check-env:
	@if [ ! -f .env ]; then \
		echo "WARNING: .env file is missing. Default values will be used."; \
	fi

status: ## Shows status of all containers
	docker compose ps

init: ## Runs the project initialization script
	@test -x scripts/init.sh || chmod +x scripts/init.sh
	@scripts/init.sh

up: check-env ## Starts Apache (web) and SQL (db)
	@docker compose up -d lamp.web lamp.db

up-pma: check-env ## Starts phpMyAdmin (pma)
	@COMPOSE_PROFILES=with-pma docker compose up -d lamp.pma

up-redis: check-env ## Starts Redis (redis)
	@COMPOSE_PROFILES=with-redis docker compose up -d lamp.redis

up-mailpit: check-env ## Starts Mailpit (mailpit)
	@COMPOSE_PROFILES=with-mailpit docker compose up -d lamp.mailpit

up-all: check-env ## Starts all services: Apache (web), SQL (db), phpMyAdmin (pma), Redis (redis), Mailpit (mailpit)
	@COMPOSE_PROFILES=with-redis,with-pma,with-mailpit docker compose up -d lamp.web lamp.db lamp.redis lamp.pma lamp.mailpit

build: ## Builds all containers using cache
	@docker compose build

build-no-cache: ## Builds all containers without cache
	@docker compose build --no-cache

switch-php: ## Rebuilds Apache (web) container after PHP version change
	@docker compose build lamp.web
	@$(MAKE) restart

switch-db: ## Rebuilds SQL (db) container after SQL version change
	@docker compose build lamp.db
	@$(MAKE) restart

restart: ## Stops and restarts core containers Apache (web) and SQL (db)
	@$(MAKE) down
	@$(MAKE) up

restart-all: ## Stops and restarts all containers
	@COMPOSE_PROFILES=$(ALL_PROFILES) docker compose down --volumes --remove-orphans
	@COMPOSE_PROFILES=$(ALL_PROFILES) docker compose up -d lamp.web lamp.db lamp.pma lamp.redis lamp.mailpit

down: ## Stops and removes all containers, volumes, and orphans
	@COMPOSE_PROFILES=$(ALL_PROFILES) docker compose down --volumes --remove-orphans

logs: ## Tails logs for all containers (live view)
	docker compose logs -f --tail=50

logs-web: ## Tails Apache (web) log
	docker logs -f web

logs-php: ## Tails only PHP-related entries from Apache (web) error log
	tail -f var/log/apache/error.log | grep PHP

logs-db: ## Tails SQL (db) logs
	docker logs -f db

logs-pma: ## Tails phpMyAdmin (pma) logs
	docker logs -f pma

logs-mailpit: ## Tails Mailpit (mailpit) logs
	docker logs -f mailpit

logs-redis: ## Tails Redis (redis) logs
	docker logs -f redis

clean-log: ## Fully deletes and recreates ./var/log directory
	@sudo rm -rf ./var/log
	@mkdir -p ./var/log
	@echo "./var/log has been deleted and recreated."

cli-db: ## Opens SQL CLI inside the SQL (db) container
	docker exec -it db mysql -u root -p

cert: ## Generates a local multi-domain self-signed SSL certificate
	./scripts/generate-multidomain-ssl.sh

shell: ## Opens a bash shell inside the Apache (web) container
	docker exec -it web bash

shell-db: ## Opens a bash shell inside the SQL (db) container
	docker exec -it db bash

fix-perms: ## Fixes executable permissions on scripts
	chmod +x scripts/**/*.sh

help: ## Displays this help message
	@bold=$$(tput bold); normal=$$(tput sgr0); cyan=$$(tput setaf 6); \
	echo "Usage: make [command]"; \
	echo ""; \
	echo "  $${bold}Available Commands:$${normal}"; \
	echo ""; \
	grep -E '^[a-zA-Z0-9_.-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	awk -v cyan="$$cyan" -v normal="$$normal" '{ \
		split($$0, parts, ":.*?## "); \
		cmd=parts[1]; desc=parts[2]; \
		printf "  %s%-20s%s %s\n", cyan, cmd, normal, desc \
	}'

