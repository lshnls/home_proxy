#!/bin/bash

INPUT="bridges_raw.txt"
OUTPUT="./tor/config/bridges.txt"
TMP="/tmp/bridges_valid.txt"

timeout_sec=5

> "$TMP"

while read -r line; do

    # пропускаем пустые строки
    [[ -z "$line" ]] && continue

    # пример строки:
    # obfs4 1.2.3.4:443 ABCDEF cert=xxxx iat-mode=0

    ip_port=$(echo "$line" | awk '{print $2}')
    ip=$(echo "$ip_port" | cut -d: -f1)
    port=$(echo "$ip_port" | cut -d: -f2)

    echo "Checking $ip:$port"

    if timeout $timeout_sec bash -c "</dev/tcp/$ip/$port" 2>/dev/null; then
        echo "OK: $ip:$port"
        echo "Bridge $line" >> "$TMP"
    else
        echo "FAIL: $ip:$port"
    fi

done < "$INPUT"

# копируем валидные мосты
cp "$TMP" "$OUTPUT"

echo "Saved valid bridges to $OUTPUT"

make restart-tor
echo "Restart tor"
