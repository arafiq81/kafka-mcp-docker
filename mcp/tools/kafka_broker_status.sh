#!/bin/bash
# Broker status (read-only)
# Usage: kafka_broker_status.sh <broker_id>

set -e

BROKER_ID="$1"
if [ -z "$BROKER_ID" ]; then
  echo '{"status":"error","message":"broker_id is required"}'
  exit 1
fi

CONTAINER="kafka${BROKER_ID}"

# Check container status and port
STATUS=$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo "unknown")
PORT_CHECK=$(docker exec "$CONTAINER" sh -c "command -v ss >/dev/null 2>&1 && ss -ltn | grep -q ':9093 ' && echo listening || echo not_listening" 2>/dev/null || echo unknown)

printf '{"status":"ok","broker_id":"%s","container":"%s","state":"%s","port_9093":"%s"}\n' \
  "$BROKER_ID" "$CONTAINER" "$STATUS" "$PORT_CHECK"
