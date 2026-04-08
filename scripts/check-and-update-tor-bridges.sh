#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

INPUT="${INPUT:-bridges_raw.txt}"
OUTPUT="${OUTPUT:-./tor/config/bridges.txt}"
TIMEOUT_SEC="${TIMEOUT_SEC:-5}"

if [[ ! -f "$INPUT" ]]; then
	echo "Ошибка: файл со списком мостов не найден: $INPUT" >&2
	exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

check_bridge() {
	local ip="$1"
	local port="$2"

	timeout "$TIMEOUT_SEC" bash -c "exec 3<>/dev/tcp/$ip/$port" 2>/dev/null
}

while IFS= read -r line; do
	# Пропускаем пустые строки и комментарии
	[[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

	# Пример строки:
	# obfs4 1.2.3.4:443 ABCDEF cert=xxxx iat-mode=0
	read -r -a parts <<<"$line"
	ip_port="${parts[1]:-}"
	[[ -z "$ip_port" ]] && continue

	ip="${ip_port%:*}"
	port="${ip_port##*:}"

	# Если в строке нет корректного порта, пропускаем.
	[[ "$port" =~ ^[0-9]+$ ]] || continue

	echo "Checking $ip:$port"

	if check_bridge "$ip" "$port"; then
		echo "OK: $ip:$port"
		echo "Bridge $line" >> "$TMP"
	else
		echo "FAIL: $ip:$port"
	fi
done < "$INPUT"

# Обновляем файл только если содержимое изменилось.
if [[ ! -f "$OUTPUT" ]] || ! cmp -s "$TMP" "$OUTPUT"; then
	cp "$TMP" "$OUTPUT"
	echo "Saved valid bridges to $OUTPUT"
else
	echo "No bridge changes detected, skip update"
fi

make restart-tor
echo "Restart tor"
