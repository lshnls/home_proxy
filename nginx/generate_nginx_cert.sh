#!/bin/sh
set -euo pipefail

CERT_DIR=/etc/nginx/certs/

mkdir -p "$CERT_DIR"

if [ ! -f "$CERT_DIR/NginxCA.key" ] || [ ! -f "$CERT_DIR/NginxCA.crt" ]; then
  # Generate CA key
  openssl genrsa -out "$CERT_DIR/NginxCA.key" 4096

  # Generate CA certificate
  openssl req -new -x509 -days 3650 \
    -key "$CERT_DIR/NginxCA.key" \
    -out "$CERT_DIR/NginxCA.crt" \
    -subj "/C=XX/O=Nginx/CN=Nginx CA"

  # Generate server key
  openssl genrsa -out "$CERT_DIR/server.key" 4096

  # Generate CSR with SANs
  openssl req -new \
    -key "$CERT_DIR/server.key" \
    -out "$CERT_DIR/server.csr" \
    -subj "/C=XX/O=Nginx/CN=*.server-arch" \
    -addext "subjectAltName=DNS:*.asfera.keenetic.pro,DNS:*.server-arch,DNS:aristarh.server-arch"

  # Sign server cert with CA
  openssl x509 -req \
    -days 3650 \
    -in "$CERT_DIR/server.csr" \
    -CA "$CERT_DIR/NginxCA.crt" \
    -CAkey "$CERT_DIR/NginxCA.key" \
    -CAcreateserial \
    -out "$CERT_DIR/server.crt" \
    -extfile <(printf "subjectAltName=DNS:*.asfera.keenetic.pro,DNS:*.server-arch,DNS:aristarh.server-arch")

  # Create chain with server cert + CA cert for nginx
  cat "$CERT_DIR/server.crt" "$CERT_DIR/NginxCA.crt" > "$CERT_DIR/chain.crt"

  # Cleanup CSR
  rm -f "$CERT_DIR/server.csr"
fi

chmod 600 "$CERT_DIR/NginxCA.key" "$CERT_DIR/NginxCA.pem"
chmod 644 "$CERT_DIR/NginxCA.crt"

exec "$@"
