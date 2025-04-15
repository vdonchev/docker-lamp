.PHONY: up up-pma up-redis up-all init rebuild down logs

# 🟢 Генерира vhosts локално и стартира основните контейнери (без lamp.init)
up:
	@echo " ✔ Generating vhost file"
	./scripts/generate-vhosts.sh
	docker compose up -d --scale lamp.init=0 lamp.web lamp.db

# 🟡 Стартира с phpMyAdmin
up-pma:
	@echo " ✔ Generating vhost file"
	./scripts/generate-vhosts.sh
	docker compose up -d --scale lamp.init=0 lamp.web lamp.db lamp.pma

# 🔴 Стартира с Redis
up-redis:
	@echo " ✔ Generating vhost file"
	./scripts/generate-vhosts.sh
	COMPOSE_PROFILES=with-redis docker compose up -d --scale lamp.init=0 lamp.web lamp.db lamp.redis

# 🟣 Стартира ВСИЧКО (phpMyAdmin + Redis)
up-all:
	@echo " ✔ Generating vhost file"
	@./scripts/generate-vhosts.sh
	@COMPOSE_PROFILES=with-redis,with-pma docker compose up -d --scale lamp.init=0

# 🧱 Старт на lamp.init контейнера (ако искаш ръчно вътре в compose)
init:
	docker compose run --rm lamp.init

# ♻️ Спира всичко и стартира отново (без lamp.init)
rebuild:
	docker compose down --volumes
	$(MAKE) up

# ⛔ Спира и премахва всичко
down:
	COMPOSE_PROFILES=with-redis,with-pma docker compose down --volumes --remove-orphans


# 📄 Гледаш логовете на Apache
logs:
	docker logs -f apache-php84
