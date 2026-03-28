#!/bin/sh
set -euo pipefail

CERT_DIR=/etc/squid/ssl

mkdir -p "$CERT_DIR" 

if [ ! -f "$CERT_DIR/squidCA.key" ] || [ ! -f "$CERT_DIR/squidCA.crt" ]; then
  openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
    -subj "/C=XX/O=Squid Proxy/CN=Squid MITM CA" \
    -keyout "$CERT_DIR/squidCA.key" \
    -out "$CERT_DIR/squidCA.crt"
fi

  cat "$CERT_DIR/squidCA.crt" "$CERT_DIR/squidCA.key" > "$CERT_DIR/squidCA.pem"
  chmod 600 "$CERT_DIR/squidCA.key"  "$CERT_DIR/squidCA.crt" "$CERT_DIR/squidCA.pem"

exec "$@"
