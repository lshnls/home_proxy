.PHONY: help build up down logs clean restart shell ps

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
	docker-compose build

up:
	@echo "Запуск сервисов..."
	docker-compose up -d
	@echo "Проверка статуса..."
	docker-compose ps

down:
	@echo "Остановка сервисов..."
	docker-compose down

ps:
	docker-compose ps

logs:
	docker-compose logs -f

logs-tor:
	docker-compose logs -f tor

logs-unbound:
	docker-compose logs -f unbound

logs-squid:
	docker-compose logs -f squid

logs-privoxy:
	docker-compose logs -f privoxy

clean:
	@echo "Удаление контейнеров..."
	docker-compose down -v
	@echo "Очистка завершена"

restart:
	@echo "Перезагрузка контейнеров..."
	docker-compose restart

shell:
	docker-compose exec squid /bin/bash

shell-tor:
	docker-compose exec tor /bin/bash

shell-unbound:
	docker-compose exec unbound /bin/bash

# Тесты
test-dns:
	@echo "=== Проверка DNS (Unbound) ==="
	dig @127.0.0.1 google.com || echo "DNS не работает"

test-tor:
	@echo "=== Проверка SOCKS (Tor) ==="
	curl -s -x socks5://127.0.0.1:9050 https://check.torproject.org/api/ip || echo "Tor SOCKS не доступен"

test-proxy:
	@echo "=== Проверка HTTP прокси (Privoxy) ==="
	curl -s -x http://127.0.0.1:8118 https://check.torproject.org/api/ip || echo "Privoxy не доступен"

test-squid:
	@echo "=== Проверка Squid прокси ==="
	curl -s -x http://127.0.0.1:3128 https://api.ipify.org?format=json || echo "Squid не доступен"

test-all: test-dns test-tor test-proxy test-squid
	@echo "=== Все тесты завершены ==="

# Управление отдельными сервисами
up-tor:
	docker-compose up -d tor

up-unbound:
	docker-compose up -d unbound

up-squid:
	docker-compose up -d squid

up-privoxy:
	docker-compose up -d privoxy

restart-tor:
	docker-compose restart tor

restart-squid:
	docker-compose restart squid

status:
	@echo "=== Статус контейнеров ==="
	docker-compose ps
	@echo ""
	@echo "=== Использование памяти ==="
	docker stats --no-stream home_proxy_*

# Утилиты
version:
	@echo "=== Docker версии ==="
	docker --version
	docker-compose --version
