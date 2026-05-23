#!/bin/sh
set -euo pipefail

CERT_DIR=/etc/squid/ssl
LOG_DIR=/var/log/squid

mkdir -p "$CERT_DIR"
mkdir -p "$LOG_DIR"
chown squid:squid "$LOG_DIR"
touch "$LOG_DIR/access.log" "$LOG_DIR/cache.log"
chown squid:squid "$LOG_DIR/access.log" "$LOG_DIR/cache.log"

# Cleanup stale locks and pid
find /var/spool/squid -name '*.lock' -type f -delete 2>/dev/null || true
rm -f /var/run/squid.pid 2>/dev/null || true

if [ ! -f "$CERT_DIR/squidCA.key" ] || [ ! -f "$CERT_DIR/squidCA.crt" ]; then
  openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
    -subj "/C=XX/O=Squid Proxy/CN=Squid MITM CA" \
    -keyout "$CERT_DIR/squidCA.key" \
    -out "$CERT_DIR/squidCA.crt"
fi

  cat "$CERT_DIR/squidCA.crt" "$CERT_DIR/squidCA.key" > "$CERT_DIR/squidCA.pem"
  chmod 600 "$CERT_DIR/squidCA.key" "$CERT_DIR/squidCA.pem"
  chmod 644 "$CERT_DIR/squidCA.crt"

# Start squid in background, then tail logs to stdout
squid -N -f /etc/squid/squid.conf &
SQUID_PID=$!

# Tail access log and cache log to stdout
tail -f "$LOG_DIR/access.log" "$LOG_DIR/cache.log" &
TAIL_PID=$!

# Wait for either process to exit
wait $SQUID_PID 2>/dev/null || true
wait $TAIL_PID 2>/dev/null || true
