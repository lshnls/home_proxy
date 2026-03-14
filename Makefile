.PHONY: help build up down logs clean restart shell ps logs-tor logs-unbound logs-squid logs-privoxy shell-tor shell-unbound test-dns test-tor test-proxy test-squid test-all up-tor up-unbound up-squid up-privoxy restart-tor restart-squid status version

COMPOSE := $(shell if docker compose version >/dev/null 2>&1; then echo "docker compose"; else echo "docker-compose"; fi)
CURL_TIMEOUT ?= 10

help:
	@echo "=== Home Proxy Docker Compose Commands ==="
	@echo ""
	@echo "Доступные команды:"
	@echo "  make up           - Запустить все сервисы"
	@echo "  make down         - Остановить все сервисы"
	@echo "  make ps           - Показать статус контейнеров"
	@echo "  make logs         - Показать логи всех сервисов"
	@echo "  make clean        - Остановить и удалить контейнеры"
	@echo "  make restart      - Перезагрузить контейнеры"
	@echo "  make shell        - Войти в shell Squid контейнера"
	@echo "  make test-dns     - Проверить DNS"
	@echo "  make test-tor     - Проверить SOCKS (Tor)"
	@echo "  make test-proxy   - Проверить HTTP прокси"
	@echo ""

build:
	$(COMPOSE) build

up:
	@echo "Запуск сервисов..."
	$(COMPOSE) up -d
	@echo "Проверка статуса..."
	$(COMPOSE) ps

down:
	@echo "Остановка сервисов..."
	$(COMPOSE) down

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

logs-tor:
	$(COMPOSE) logs -f tor

logs-unbound:
	$(COMPOSE) logs -f unbound

logs-squid:
	$(COMPOSE) logs -f squid

logs-privoxy:
	$(COMPOSE) logs -f privoxy

clean:
	@echo "Удаление контейнеров..."
	$(COMPOSE) down -v
	@echo "Очистка завершена"

restart:
	@echo "Перезагрузка контейнеров..."
	$(COMPOSE) restart

shell:
	$(COMPOSE) exec squid /bin/bash

shell-tor:
	$(COMPOSE) exec tor /bin/bash

shell-unbound:
	$(COMPOSE) exec unbound /bin/bash

# Тесты
test-dns:
	@echo "=== Проверка DNS (Unbound) ==="
	dig @127.0.0.1 google.com || echo "DNS не работает"

test-tor:
	@echo "=== Проверка SOCKS (Tor) ==="
	curl -sS --max-time $(CURL_TIMEOUT) -x socks5://127.0.0.1:9050 https://check.torproject.org/api/ip || echo "Tor SOCKS не доступен"

test-proxy:
	@echo "=== Проверка HTTP прокси (Privoxy) ==="
	curl -sS --max-time $(CURL_TIMEOUT) -x http://127.0.0.1:8118 https://check.torproject.org/api/ip || echo "Privoxy не доступен"

test-squid:
	@echo "=== Проверка Squid прокси ==="
	curl -sS --max-time $(CURL_TIMEOUT) -x http://127.0.0.1:3128 https://api.ipify.org?format=json || echo "Squid не доступен"

test-all: test-dns test-tor test-proxy test-squid
	@echo "=== Все тесты завершены ==="

# Управление отдельными сервисами
up-tor:
	$(COMPOSE) up -d tor

up-unbound:
	$(COMPOSE) up -d unbound

up-squid:
	$(COMPOSE) up -d squid

up-privoxy:
	$(COMPOSE) up -d privoxy

restart-tor:
	$(COMPOSE) restart tor

restart-squid:
	$(COMPOSE) restart squid

status:
	@echo "=== Статус контейнеров ==="
	$(COMPOSE) ps
	@echo ""
	@echo "=== Использование памяти ==="
	docker stats --no-stream home_proxy_*

# Утилиты
version:
	@echo "=== Docker версии ==="
	docker --version
	$(COMPOSE) version
