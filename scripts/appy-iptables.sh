
# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IPTABLES_RULES_FILE="$PROJECT_ROOT/iptables.rules"

# Интерфейс и порты (можно переопределить через переменные окружения)
LAN_IFACE="${HOME_PROXY_LAN_IFACE:-enp0s31f6}"
SQUID_HTTP_PORT="${SQUID_HTTP_PORT:-8081}"
SQUID_HTTPS_PORT="${SQUID_HTTPS_PORT:-8082}"

# Локальные сети, которые не нужно проксировать
LOCAL_NETS=(
    "127.0.0.0/8"
    "192.168.0.0/16"
    "10.0.0.0/8"
    "172.16.0.0/12"
)

usage() {
    echo "Использование: $0 {apply|clear|save|show}"
    echo ""
    echo "Команды:"
    echo "  apply  - Применить правила прозрачного проксирования"
    echo "  clear  - Очистить все правила NAT для прозрачного прокси"
    echo "  save   - Сохранить текущие правила в файл iptables.rules"
    echo "  show   - Показать текущие правила"
    echo ""
    echo "Переменные окружения:"
    echo "  HOME_PROXY_LAN_IFACE  - Сетевой интерфейс локальной сети (по умолчанию: enp0s31f6)"
    echo "  SQUID_HTTP_PORT       - Порт Squid для HTTP (по умолчанию: 8081)"
    echo "  SQUID_HTTPS_PORT      - Порт Squid для HTTPS (по умолчанию: 8082)"
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Ошибка: скрипт должен быть запущен от root (используйте sudo)"
        exit 1
    fi
}

clear_proxy_rules() {
    echo "Очистка правил прозрачного проксирования..."

    # Удаляем правила перенаправления портов
    iptables -t nat -D PREROUTING -i "$LAN_IFACE" -p tcp --dport 80 -j REDIRECT --to-ports "$SQUID_HTTP_PORT" 2>/dev/null || true
    iptables -t nat -D PREROUTING -i "$LAN_IFACE" -p tcp --dport 443 -j REDIRECT --to-ports "$SQUID_HTTPS_PORT" 2>/dev/null || true

    # Удаляем правила исключения локальных сетей
    for net in "${LOCAL_NETS[@]}"; do
        iptables -t nat -D PREROUTING -d "$net" -i "$LAN_IFACE" -j RETURN 2>/dev/null || true
    done

    # Удаляем правило исключения loopback
    iptables -t nat -D PREROUTING -i lo -j RETURN 2>/dev/null || true

    echo "Правила очищены."
}

apply_proxy_rules() {
    echo "Применение правил прозрачного проксирования..."
    echo "Интерфейс: $LAN_IFACE"
    echo "HTTP порт: $SQUID_HTTP_PORT"
    echo "HTTPS порт: $SQUID_HTTPS_PORT"

    # Сначала очищаем старые правила
    clear_proxy_rules

    # Исключаем loopback интерфейс
    echo "Добавление правила исключения loopback..."
    iptables -t nat -A PREROUTING -i lo -j RETURN

    # Исключаем локальные сети
    echo "Добавление правил исключения локальных сетей..."
    for net in "${LOCAL_NETS[@]}"; do
        echo "  - $net"
        iptables -t nat -A PREROUTING -d "$net" -i "$LAN_IFACE" -j RETURN
    done

    # Перенаправляем HTTP трафик на Squid
    echo "Перенаправление HTTP (порт 80) на порт $SQUID_HTTP_PORT..."
    iptables -t nat -A PREROUTING -i "$LAN_IFACE" -p tcp --dport 80 -j REDIRECT --to-ports "$SQUID_HTTP_PORT"

    # Перенаправляем HTTPS трафик на Squid
    echo "Перенаправление HTTPS (порт 443) на порт $SQUID_HTTPS_PORT..."
    iptables -t nat -A PREROUTING -i "$LAN_IFACE" -p tcp --dport 443 -j REDIRECT --to-ports "$SQUID_HTTPS_PORT"

    echo ""
    echo "Правила успешно применены!"
    echo ""
    echo "Для сохранения правил выполните: $0 save"
}

save_rules() {
    echo "Сохранение текущих правил в $IPTABLES_RULES_FILE..."
    iptables-save > "$IPTABLES_RULES_FILE"
    echo "Правила сохранены."
}

show_rules() {
    echo "Текущие правила NAT:"
    iptables -t nat -L PREROUTING -v -n --line-numbers
    echo ""
    echo "Все правила iptables:"
    iptables-save
}

# Проверка прав
check_root

# Обработка команд
case "${1:-}" in
    apply)
        apply_proxy_rules
        ;;
    clear)
        clear_proxy_rules
        ;;
    save)
        save_rules
        ;;
    show)
        show_rules
        ;;
    *)
        usage
        ;;
esac
