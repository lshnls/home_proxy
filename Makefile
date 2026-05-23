.PHONY: help build up down logs clean restart shell ps logs-tor logs-unbound logs-squid logs-nginx logs-privoxy shell-tor shell-unbound test-dns test-tor test-proxy test-squid test-all up-tor up-unbound up-squid up-nginx up-privoxy restart-tor restart-squid restart-nginx status version

COMPOSE := $(shell if docker compose version >/dev/null 2>&1; then echo "docker compose"; else echo "docker-compose"; fi)
CURL_TIMEOUT ?= 10

# Порты для тестов (те же переменные, что у docker compose)
PROJECT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
-include $(PROJECT_DIR).env
UNBOUND_PORT ?= 53
TOR_SOCKS_PORT ?= 9050
PRIVOXY_PORT ?= 8118
SQUID_PORT ?= 3128

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

logs-nginx:
	$(COMPOSE) logs -f nginx

logs-nginx:
	$(COMPOSE) logs -f nginx

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

# Тесты (порты из .env: UNBOUND_PORT, TOR_SOCKS_PORT, PRIVOXY_PORT, SQUID_PORT)
test-dns:
	@echo "=== Проверка DNS (Unbound, порт $(UNBOUND_PORT)) ==="
	dig @127.0.0.1 -p $(UNBOUND_PORT) google.com || echo "DNS не работает"

test-tor:
	@echo "=== Проверка SOCKS (Tor, порт $(TOR_SOCKS_PORT)) ==="
	curl -sS --max-time $(CURL_TIMEOUT) -x socks5://127.0.0.1:$(TOR_SOCKS_PORT) https://check.torproject.org/api/ip || echo "Tor SOCKS не доступен"

test-proxy:
	@echo "=== Проверка HTTP прокси (Privoxy, порт $(PRIVOXY_PORT)) ==="
	curl -sS --max-time $(CURL_TIMEOUT) -x http://127.0.0.1:$(PRIVOXY_PORT) https://check.torproject.org/api/ip || echo "Privoxy не доступен"

test-squid:
	@echo "=== Проверка Squid прокси (порт $(SQUID_PORT)) ==="
	curl -sS --max-time $(CURL_TIMEOUT) -x http://127.0.0.1:$(SQUID_PORT) https://api.ipify.org?format=json || echo "Squid не доступен"

test-all: test-dns test-squid test-proxy test-tor
	@echo "=== Все тесты завершены ==="

# Управление отдельными сервисами
up-tor:
	$(COMPOSE) up -d tor

up-unbound:
	$(COMPOSE) up -d unbound

up-squid:
	$(COMPOSE) up -d squid

up-nginx:
	$(COMPOSE) up -d nginx

up-privoxy:
	$(COMPOSE) up -d privoxy

restart-tor:
	$(COMPOSE) restart tor

restart-squid:
	$(COMPOSE) restart squid

restart-nginx:
	$(COMPOSE) restart nginx

status:
	@echo "=== Статус контейнеров ==="
	$(COMPOSE) ps
	@echo ""
	@echo "=== Использование памяти ==="
	@ids="$$($(COMPOSE) ps -q)"; \
	if [ -n "$$ids" ]; then \
		docker stats --no-stream $$ids; \
	else \
		echo "Нет запущенных контейнеров"; \
	fi

# Утилиты
version:
	@echo "=== Docker версии ==="
	docker --version
	$(COMPOSE) version
