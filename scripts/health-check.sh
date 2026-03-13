#!/bin/bash
# Скрипт для проверки состояния всех сервисов

set -e

echo "=== Проверка состояния Home Proxy сервисов ==="
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для проверки
check_service() {
    local service=$1
    local port=$2
    local protocol=${3:-tcp}
    
    if nc -z -w5 127.0.0.1 $port 2>/dev/null; then
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

RUNNING=$(docker-compose ps --services --filter "status=running" | wc -l)
TOTAL=$(docker-compose ps --services | wc -l)

echo "Запущено контейнеров: $RUNNING из $TOTAL"
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
docker-compose ps

echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Все сервисы работают корректно${NC}"
    exit 0
else
    echo -e "${RED}✗ Некоторые сервисы не работают${NC}"
    exit 1
fi
