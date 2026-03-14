#!/usr/bin/env bash
# Скрипт для проверки состояния всех сервисов

set -euo pipefail

# Таймаут проверок портов (сек)
CHECK_TIMEOUT="${CHECK_TIMEOUT:-1}"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Выбор команды compose (docker compose plugin или docker-compose)
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
else
    echo -e "${RED}✗${NC} Не найдено ни 'docker compose', ни 'docker-compose'"
    exit 1
fi

echo "=== Проверка состояния Home Proxy сервисов ==="
echo ""

# Функция для проверки
check_service() {
    local service="$1"
    local port="$2"

    if nc -z -w"$CHECK_TIMEOUT" 127.0.0.1 "$port" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $service (порт $port) - работает"
        return 0
    else
        echo -e "${RED}✗${NC} $service (порт $port) - не работает"
        return 1
    fi
}

# Проверка контейнеров
echo "Статус контейнеров:"
echo ""

# Минимизируем число вызовов docker compose: один список сервисов + один список running
mapfile -t ALL_SERVICES < <("${COMPOSE_CMD[@]}" ps --services)
mapfile -t RUNNING_SERVICES < <("${COMPOSE_CMD[@]}" ps --services --filter "status=running")

TOTAL="${#ALL_SERVICES[@]}"
RUNNING="${#RUNNING_SERVICES[@]}"

echo "Запущено контейнеров: $RUNNING из $TOTAL"

if (( TOTAL > 0 && RUNNING < TOTAL )); then
    echo -e "${YELLOW}!${NC} Не все контейнеры запущены"
fi

echo ""

# Детальная проверка
echo "Проверка портов:"
echo ""

FAILED=0

check_service "Unbound DNS" 53 || ((FAILED++))
check_service "Tor SOCKS" 9050 || ((FAILED++))
check_service "Privoxy" 8118 || ((FAILED++))
check_service "Squid" 3128 || ((FAILED++))

echo ""
echo "Статус Docker контейнеров:"
"${COMPOSE_CMD[@]}" ps

echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ Все сервисы работают корректно${NC}"
    exit 0
else
    echo -e "${RED}✗ Некоторые сервисы не работают${NC}"
    exit 1
fi
