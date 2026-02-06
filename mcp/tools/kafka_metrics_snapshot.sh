#!/bin/bash
# Best-effort JMX port check (read-only).
# Usage: kafka_metrics_snapshot.sh <broker_id>

set -e

BROKER_ID="$1"
if [ -z "$BROKER_ID" ]; then
  echo '{"status":"error","message":"broker_id is required"}'
  exit 1
fi

# Map broker to container and JMX port (host side)
case "$BROKER_ID" in
  1) CONTAINER=kafka1; JMX_PORT=9101;;
  2) CONTAINER=kafka2; JMX_PORT=9101;;
  3) CONTAINER=kafka3; JMX_PORT=9101;;
  *) echo '{"status":"error","message":"broker_id must be 1,2,3"}'; exit 1;;
 esac

# Check if JMX port is listening inside the container
OUT=$(docker exec "$CONTAINER" sh -c "command -v ss >/dev/null 2>&1 && ss -ltn | grep -q ':$JMX_PORT ' && echo LISTENING || echo NOT_LISTENING" 2>&1) || true

STATUS="unknown"
if [ "$OUT" = "LISTENING" ]; then
  STATUS="listening"
elif [ "$OUT" = "NOT_LISTENING" ]; then
  STATUS="not_listening"
fi

printf '{"status":"ok","broker_id":"%s","jmx_port":%s,"jmx_status":"%s","note":"Use JMX tools for detailed metrics"}\n' \
  "$BROKER_ID" "$JMX_PORT" "$STATUS"
