#!/usr/bin/env bash
# Применение правил прозрачного прокси (Squid intercept) с учётом Docker.
#
# Полный iptables-restore по файлу затирает цепочки DOCKER в nat/filter — проброс
# портов контейнеров и маршрутизация ломаются. Здесь только свои цепочки + точечные -I/-A.
#
# Порты сервисов читаются из .env в корне проекта (как в docker-compose).
# Интерфейс LAN задаётся явно (см. ниже).
#
# Использование:
#   sudo HOME_PROXY_LAN_IFACE=enp0s31f6 ./scripts/iptables.sh apply
#   sudo ./scripts/iptables.sh remove
#   ./scripts/iptables.sh status
#
# Рекомендуется вызывать apply после «docker compose up -d», чтобы подставить имя
# bridge сети compose (или задайте HOME_PROXY_DOCKER_BRIDGE вручную).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

if [[ -f .env ]]; then
	set -a
	# shellcheck source=/dev/null
	source .env
	set +a
fi

UNBOUND_PORT="${UNBOUND_PORT:-53}"
TOR_SOCKS_PORT="${TOR_SOCKS_PORT:-9050}"
PRIVOXY_PORT="${PRIVOXY_PORT:-8118}"
SQUID_PORT="${SQUID_PORT:-3128}"
SQUID_HTTP_PORT="${SQUID_HTTP_PORT:-8081}"
SQUID_HTTPS_PORT="${SQUID_HTTPS_PORT:-8082}"
DOCKER_NETWORK="${DOCKER_NETWORK:-proxy_network}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-$(basename "$ROOT_DIR")}"

# Обязательно: интерфейс стороны LAN (как enp0s31f6 в iptables/iptables.rules)
LAN_IFACE="${HOME_PROXY_LAN_IFACE:-${LAN_IFACE:-}}"
# Подсеть LAN для исключений в PREROUTING (не редиректить локальные адреса)
LAN_SUBNET="${HOME_PROXY_LAN_SUBNET:-192.168.1.0/24}"

NAT_CHAIN="HOME_PROXY_NAT"
FWD_CHAIN="HOME_PROXY_FWD"
IN_CHAIN="HOME_PROXY_IN"

IPT=(iptables -w 10)

die() {
	echo "Ошибка: $*" >&2
	exit 1
}

require_root() {
	[[ "$(id -u)" -eq 0 ]] || die "нужны права root (sudo)"
}

detect_compose_bridge() {
	local net full
	if ! command -v docker >/dev/null 2>&1; then
		echo ""
		return 0
	fi
	net="${DOCKER_NETWORK}"
	full="${COMPOSE_PROJECT_NAME}_${net}"
	if docker network inspect "$full" >/dev/null 2>&1; then
		docker network inspect "$full" --format '{{index .Options "com.docker.network.bridge.name"}}' 2>/dev/null || true
		return 0
	fi
	if docker network inspect "$net" >/dev/null 2>&1; then
		docker network inspect "$net" --format '{{index .Options "com.docker.network.bridge.name"}}' 2>/dev/null || true
		return 0
	fi
	echo ""
}

apply_nat() {
	"${IPT[@]}" -t nat -N "$NAT_CHAIN" 2>/dev/null || "${IPT[@]}" -t nat -F "$NAT_CHAIN"

	"${IPT[@]}" -t nat -A "$NAT_CHAIN" -i "$LAN_IFACE" -d "$LAN_SUBNET" -j RETURN
	"${IPT[@]}" -t nat -A "$NAT_CHAIN" -i "$LAN_IFACE" -d 10.0.0.0/8 -j RETURN
	"${IPT[@]}" -t nat -A "$NAT_CHAIN" -i "$LAN_IFACE" -d 172.16.0.0/12 -j RETURN
	"${IPT[@]}" -t nat -A "$NAT_CHAIN" -i "$LAN_IFACE" -d 192.168.0.0/16 -j RETURN
	"${IPT[@]}" -t nat -A "$NAT_CHAIN" -i "$LAN_IFACE" -d 127.0.0.0/8 -j RETURN

	"${IPT[@]}" -t nat -A "$NAT_CHAIN" -i "$LAN_IFACE" -p tcp --dport 80 -j REDIRECT --to-ports "$SQUID_HTTP_PORT"
	"${IPT[@]}" -t nat -A "$NAT_CHAIN" -i "$LAN_IFACE" -p tcp --dport 443 -j REDIRECT --to-ports "$SQUID_HTTPS_PORT"

	if ! "${IPT[@]}" -t nat -C PREROUTING -i "$LAN_IFACE" -j "$NAT_CHAIN" 2>/dev/null; then
		# В начале PREROUTING: перехват LAN до правил DNAT Docker на локальные порты
		"${IPT[@]}" -t nat -I PREROUTING 1 -i "$LAN_IFACE" -j "$NAT_CHAIN"
	fi
}

apply_forward() {
	local br="${HOME_PROXY_DOCKER_BRIDGE:-$(detect_compose_bridge)}"
	br="$(echo -n "$br" | tr -d '[:space:]')"

	"${IPT[@]}" -N "$FWD_CHAIN" 2>/dev/null || "${IPT[@]}" -F "$FWD_CHAIN"

	"${IPT[@]}" -A "$FWD_CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
	"${IPT[@]}" -A "$FWD_CHAIN" -i docker0 -j ACCEPT
	"${IPT[@]}" -A "$FWD_CHAIN" -o docker0 -j ACCEPT
	if [[ -n "$br" ]]; then
		"${IPT[@]}" -A "$FWD_CHAIN" -i "$br" -j ACCEPT
		"${IPT[@]}" -A "$FWD_CHAIN" -o "$br" -j ACCEPT
	fi
	# Сначала блок QUIC, иначе общий ACCEPT с LAN съедает всё (как в старом iptables.rules)
	"${IPT[@]}" -A "$FWD_CHAIN" -i "$LAN_IFACE" -p udp --dport 443 -j DROP
	"${IPT[@]}" -A "$FWD_CHAIN" -i "$LAN_IFACE" -j ACCEPT
	"${IPT[@]}" -A "$FWD_CHAIN" -j RETURN

	if ! "${IPT[@]}" -C FORWARD -j "$FWD_CHAIN" 2>/dev/null; then
		# Сразу после DOCKER-USER, иначе конечный DROP/REJECT в FORWARD не дойдёт до нашей цепочки
		local line insert_at
		line=$("${IPT[@]}" -L FORWARD --line-numbers -n 2>/dev/null | awk '/DOCKER-USER/ {print $1; exit}')
		if [[ -n "$line" ]] && [[ "$line" =~ ^[0-9]+$ ]]; then
			insert_at=$((line + 1))
		else
			insert_at=1
		fi
		"${IPT[@]}" -I FORWARD "$insert_at" -j "$FWD_CHAIN"
	fi
}

apply_input() {
	"${IPT[@]}" -N "$IN_CHAIN" 2>/dev/null || "${IPT[@]}" -F "$IN_CHAIN"

	"${IPT[@]}" -A "$IN_CHAIN" -p tcp --dport 22 -j ACCEPT
	"${IPT[@]}" -A "$IN_CHAIN" -p udp --dport "$UNBOUND_PORT" -j ACCEPT
	"${IPT[@]}" -A "$IN_CHAIN" -p tcp --dport "$UNBOUND_PORT" -j ACCEPT
	"${IPT[@]}" -A "$IN_CHAIN" -p tcp --dport "$PRIVOXY_PORT" -j ACCEPT
	"${IPT[@]}" -A "$IN_CHAIN" -p tcp --dport "$TOR_SOCKS_PORT" -j ACCEPT
	"${IPT[@]}" -A "$IN_CHAIN" -p tcp --dport "$SQUID_PORT" -j ACCEPT
	"${IPT[@]}" -A "$IN_CHAIN" -p tcp --dport "$SQUID_HTTP_PORT" -j ACCEPT
	"${IPT[@]}" -A "$IN_CHAIN" -p tcp --dport "$SQUID_HTTPS_PORT" -j ACCEPT
	# Опционально: другие сервисы на хосте (как в iptables.rules)
	if [[ "${HOME_PROXY_ALLOW_HOST_HTTPS:-0}" == "1" ]]; then
		"${IPT[@]}" -A "$IN_CHAIN" -p tcp --dport 443 -j ACCEPT
	fi
	if [[ -n "${HOME_PROXY_EXTRA_TCP_PORTS:-}" ]]; then
		local p
		for p in $HOME_PROXY_EXTRA_TCP_PORTS; do
			"${IPT[@]}" -A "$IN_CHAIN" -p tcp --dport "$p" -j ACCEPT
		done
	fi
	"${IPT[@]}" -A "$IN_CHAIN" -j RETURN

	if ! "${IPT[@]}" -C INPUT -j "$IN_CHAIN" 2>/dev/null; then
		# Доп. цепочка в конце INPUT; при policy DROP нужны базовые правила (lo, ESTABLISHED) до неё
		"${IPT[@]}" -A INPUT -j "$IN_CHAIN"
	fi
}

remove_nat() {
	"${IPT[@]}" -t nat -D PREROUTING -i "$LAN_IFACE" -j "$NAT_CHAIN" 2>/dev/null || true
	"${IPT[@]}" -t nat -F "$NAT_CHAIN" 2>/dev/null || true
	"${IPT[@]}" -t nat -X "$NAT_CHAIN" 2>/dev/null || true
}

remove_forward() {
	"${IPT[@]}" -D FORWARD -j "$FWD_CHAIN" 2>/dev/null || true
	"${IPT[@]}" -F "$FWD_CHAIN" 2>/dev/null || true
	"${IPT[@]}" -X "$FWD_CHAIN" 2>/dev/null || true
}

remove_input() {
	"${IPT[@]}" -D INPUT -j "$IN_CHAIN" 2>/dev/null || true
	"${IPT[@]}" -F "$IN_CHAIN" 2>/dev/null || true
	"${IPT[@]}" -X "$IN_CHAIN" 2>/dev/null || true
}

cmd_apply() {
	require_root
	[[ -n "$LAN_IFACE" ]] || die "задайте HOME_PROXY_LAN_IFACE или LAN_IFACE (интерфейс к LAN)"

	local br="${HOME_PROXY_DOCKER_BRIDGE:-$(detect_compose_bridge)}"
	br="$(echo -n "$br" | tr -d '[:space:]')"
	echo "LAN_IFACE=$LAN_IFACE LAN_SUBNET=$LAN_SUBNET"
	echo "Порты: DNS=$UNBOUND_PORT Tor=$TOR_SOCKS_PORT Privoxy=$PRIVOXY_PORT Squid=$SQUID_PORT intercept=$SQUID_HTTP_PORT/$SQUID_HTTPS_PORT"
	if [[ -n "$br" ]]; then
		echo "Docker bridge (compose): $br"
	else
		echo "Docker bridge не определён (запустите compose или задайте HOME_PROXY_DOCKER_BRIDGE); в FORWARD останутся только docker0"
	fi

	apply_nat
	apply_forward
	apply_input

	echo "Правила применены."
}

cmd_remove() {
	require_root
	[[ -n "$LAN_IFACE" ]] || die "задайте HOME_PROXY_LAN_IFACE или LAN_IFACE (тот же, что при apply)"
	remove_nat
	remove_forward
	remove_input
	echo "Цепочки HOME_PROXY_* и переходы из PREROUTING/FORWARD/INPUT сняты."
}

cmd_status() {
	echo "=== nat: цепочка $NAT_CHAIN ==="
	"${IPT[@]}" -t nat -S "$NAT_CHAIN" 2>/dev/null || echo "(нет)"
	echo ""
	echo "=== filter: $FWD_CHAIN ==="
	"${IPT[@]}" -S "$FWD_CHAIN" 2>/dev/null || echo "(нет)"
	echo ""
	echo "=== filter: $IN_CHAIN ==="
	"${IPT[@]}" -S "$IN_CHAIN" 2>/dev/null || echo "(нет)"
	echo ""
	echo "=== filter: FORWARD (номера строк, начало) ==="
	"${IPT[@]}" -L FORWARD --line-numbers -n 2>/dev/null | head -15 || true
}

case "${1:-}" in
	apply) cmd_apply ;;
	remove) cmd_remove ;;
	status) cmd_status ;;
	*)
		echo "Использование: $0 apply|remove|status" >&2
		echo "Переменные: HOME_PROXY_LAN_IFACE, HOME_PROXY_LAN_SUBNET, HOME_PROXY_DOCKER_BRIDGE, HOME_PROXY_ALLOW_HOST_HTTPS=1, HOME_PROXY_EXTRA_TCP_PORTS=\"5000 8443\"" >&2
		exit 1
		;;
esac
