.PHONY: up up-pma up-redis up-all build restart rebuild down logs cert shell fix-perms

# Starts main containers (lamp.web + lamp.db)
up:
	@docker compose up -d lamp.web lamp.db

# Starts containers with phpMyAdmin
up-pma:
	@COMPOSE_PROFILES=with-pma docker compose up -d lamp.web lamp.db lamp.pma

# Starts containers with Redis
up-redis:
	@COMPOSE_PROFILES=with-redis docker compose up -d lamp.web lamp.db lamp.redis

# Starts all containers (phpMyAdmin + Redis)
up-all:
	@COMPOSE_PROFILES=with-redis,with-pma docker compose up -d lamp.web lamp.db lamp.redis lamp.pma

# Builds all containers without cache
build:
	@docker compose build --no-cache

# Stops and starts the current active config
restart:
	@$(MAKE) down
	@$(MAKE) up

# Stops all containers and starts fresh (without volumes)
rebuild:
	@docker compose down --volumes
	@$(MAKE) up

# Completely stops and removes all containers, volumes, and orphans
down:
	@COMPOSE_PROFILES=with-redis,with-pma docker compose down --volumes --remove-orphans

# Follows Apache logs
logs:
	docker logs -f apache-${PHP_VERSION}

# Generates a multidomain self-signed SSL certificate
cert:
	./scripts/generate-multidomain-ssl.sh

# Opens a bash shell inside the Apache container
shell:
	docker exec -it apache-${PHP_VERSION} bash

# Fixes executable permissions on shell scripts
fix-perms:
	chmod +x entrypoint.sh scripts/*.sh
