#!/bin/bash
# Show TLS cert expiry info (read-only).
# Usage: kafka_tls_status.sh <broker_id|--all>

set -e

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo '{"status":"error","message":"broker_id or --all required"}'
  exit 1
fi

CERT_DIR="$(cd "$(dirname "$0")/../../docker/certs" && pwd)"

check_cert() {
  local broker="$1"
  local cert="$CERT_DIR/${broker}/${broker}.crt"
  if [ ! -f "$cert" ]; then
    printf '{"broker":"%s","status":"error","message":"cert not found"}' "$broker"
    return
  fi
  local end
  end=$(openssl x509 -in "$cert" -noout -enddate | sed 's/notAfter=//')
  printf '{"broker":"%s","status":"ok","not_after":"%s"}' "$broker" "$end"
}

if [ "$TARGET" = "--all" ]; then
  printf '{"status":"ok","results":[%s,%s,%s]}\n' \
    "$(check_cert kafka1)" "$(check_cert kafka2)" "$(check_cert kafka3)"
  exit 0
fi

case "$TARGET" in
  1) check_cert kafka1;;
  2) check_cert kafka2;;
  3) check_cert kafka3;;
  *) echo '{"status":"error","message":"broker_id must be 1,2,3 or --all"}'; exit 1;;
 esac

