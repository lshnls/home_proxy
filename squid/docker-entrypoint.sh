#!/bin/sh
set -euo pipefail

CERT_DIR=/etc/squid/ssl

mkdir -p "$CERT_DIR" 


openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
  -subj "/C=XX/O=Squid Proxy/CN=Squid MITM CA" \
  -keyout "$CERT_DIR/squidCA.key" \
  -out "$CERT_DIR/squidCA.crt"

  #cat "$CERT_DIR/squidCA.crt" "$CERT_DIR/squidCA.key" > "$CERT_DIR/squidCA.pem"
  chmod 600 "$CERT_DIR/squidCA.key" "$CERT_DIR/squidCA.crt"

exec "$@"