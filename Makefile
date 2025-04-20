.PHONY: check-env status up up-pma up-redis up-mailhog up-all build build-no-cache switch-php switch-sql restart \
		restart-all down logs logs-php logs-sql logs-pma logs-mailhog logs-redis logs-all \
		clean-log mysql-cli cert shell shell-sql fix-perms help

.DEFAULT_GOAL := help

PHP_VERSION ?= php84
SQL_VERSION ?= mysql84
SQL_ROOT_PWD ?= root
ALL_PROFILES := with-redis,with-pma,with-mailhog

# Internal target: checks if .env exists
check-env:
	@if [ ! -f .env ]; then \
		echo "WARNING: .env file is missing. Default values will be used."; \
	fi

status: ## Shows status of all containers
	docker compose ps

up: check-env ## Starts Apache (lamp.web) and MySQL (lamp.db)
	@docker compose up -d lamp.web lamp.db

up-pma: check-env ## Starts lamp.web, lamp.db, and phpMyAdmin (lamp.pma)
	@COMPOSE_PROFILES=with-pma docker compose up -d lamp.web lamp.db lamp.pma

up-redis: check-env ## Starts lamp.web, lamp.db, and Redis (lamp.redis)
	@COMPOSE_PROFILES=with-redis docker compose up -d lamp.web lamp.db lamp.redis

up-mailhog: check-env ## Starts lamp.web, lamp.db, and MailHog (lamp.mailhog)
	@COMPOSE_PROFILES=with-mailhog docker compose up -d lamp.web lamp.db lamp.mailhog

up-all: check-env ## Starts all services: Apache, MySQL, phpMyAdmin, Redis, MailHog
	@COMPOSE_PROFILES=with-redis,with-pma,with-mailhog docker compose up -d lamp.web lamp.db lamp.redis lamp.pma lamp.mailhog

build: ## Builds all containers using cache
	@docker compose build

build-no-cache: ## Builds all containers without cache
	@docker compose build --no-cache

switch-php: ## Rebuilds web container after PHP version change
	@docker compose build lamp.web
	@$(MAKE) restart

switch-sql: ## Rebuilds web container after PHP version change
	@docker compose build lamp.db
	@$(MAKE) restart

restart: ## Stops and restarts core containers (Apache + MySQL)
	@$(MAKE) down
	@$(MAKE) up

restart-all: ## Stops and restarts all containers including extras (pma, redis, mailhog)
	@COMPOSE_PROFILES=$(ALL_PROFILES) docker compose down --volumes --remove-orphans
	@COMPOSE_PROFILES=$(ALL_PROFILES) docker compose up -d lamp.web lamp.db lamp.pma lamp.redis lamp.mailhog

down: ## Stops and removes all containers, volumes, and orphans
	@COMPOSE_PROFILES=$(ALL_PROFILES) docker compose down --volumes --remove-orphans

logs: ## Tails Apache logs
	docker logs -f apache-$(PHP_VERSION)

logs-php: ## Tails only PHP-related entries from Apache error log
	tail -f var/log/apache/error.log | grep PHP

logs-sql: ## Tails MySQL logs
	docker logs -f $(SQL_VERSION)

logs-pma: ## Tails phpMyAdmin logs
	docker logs -f pma

logs-mailhog: ## Tails MailHog logs
	docker logs -f mailhog

logs-redis: ## Tails Redis logs
	docker logs -f redis

logs-all: ## Tails logs for all containers (live view)
	docker compose logs -f --tail=50

clean-log: ## Fully deletes and recreates ./var/log directory
	@sudo rm -rf ./var/log
	@mkdir -p ./var/log
	@echo "./var/log has been deleted and recreated."

mysql-cli: ## Opens MySQL CLI inside the database container
	docker exec -it $(SQL_VERSION) mysql -u root -p$(SQL_ROOT_PWD)

cert: ## Generates a local multi-domain self-signed SSL certificate
	./scripts/generate-multidomain-ssl.sh

shell: ## Opens a bash shell inside the Apache container
	docker exec -it apache-$(PHP_VERSION) bash

shell-sql: ## Opens a bash shell inside the MySQL container
	docker exec -it $(SQL_VERSION) bash

fix-perms: ## Fixes executable permissions on scripts
	chmod +x entrypoint.sh scripts/*.sh

help: ## Displays this help message
	@echo "Usage: make [command]"
	@echo ""
	@echo "  \033[1mAvailable Commands:\033[0m"
	@echo ""
	@grep -E '^[a-zA-Z0-9_.-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
