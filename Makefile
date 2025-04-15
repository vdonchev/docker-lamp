.PHONY: up up-pma up-redis up-all init rebuild down logs cert

# Generates vhosts and starts main containers (excluding lamp.init)
up:
	@echo " ✔ Generating vhost file"
	@./scripts/generate-vhosts.sh
	@docker compose up -d --scale lamp.init=0 lamp.web lamp.db

# Generates vhosts and starts containers with phpMyAdmin
up-pma:
	@echo " ✔ Generating vhost file"
	@./scripts/generate-vhosts.sh
	@docker compose up -d --scale lamp.init=0 lamp.web lamp.db lamp.pma

# Generates vhosts and starts containers with Redis support
up-redis:
	@echo " ✔ Generating vhost file"
	@./scripts/generate-vhosts.sh
	@COMPOSE_PROFILES=with-redis docker compose up -d --scale lamp.init=0 lamp.web lamp.db lamp.redis

# Generates vhosts and starts all containers (phpMyAdmin + Redis)
up-all:
	@echo " ✔ Generating vhost file"
	@./scripts/generate-vhosts.sh
	@COMPOSE_PROFILES=with-redis,with-pma docker compose up -d --scale lamp.init=0

# Manually runs the lamp.init container (for manual setup tasks)
init:
	docker compose run --rm lamp.init

# Stops all containers and restarts them (excluding lamp.init)
rebuild:
	@docker compose down --volumes
	@$(MAKE) up

# Completely stops and removes all containers, volumes, and orphan containers
down:
	@COMPOSE_PROFILES=with-redis,with-pma docker compose down

# Shows Apache logs (adjust container name if PHP version changes)
logs:
	docker logs -f apache-php84

# Generates a multidomain self-signed SSL certificate (dev.crt / dev.key)
cert:
	./scripts/generate-multidomain-ssl.sh
