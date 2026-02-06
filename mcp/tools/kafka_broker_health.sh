#!/bin/bash
# Basic broker health signal from container log file (read-only).
# Usage: kafka_broker_health.sh <broker_id>

set -e

BROKER_ID="$1"
if [ -z "$BROKER_ID" ]; then
  echo '{"status":"error","message":"broker_id is required"}'
  exit 1
fi

CONTAINER="kafka${BROKER_ID}"
LOG_DIR="/opt/kafka/logs"

LOG_FILE=$(docker exec "$CONTAINER" sh -c "ls -1 $LOG_DIR 2>/dev/null | grep -m1 '^server\\.log$' || ls -1 $LOG_DIR/*.log 2>/dev/null | head -n1" || true)

if [ -z "$LOG_FILE" ]; then
  echo "{\"status\":\"error\",\"message\":\"no log file found in $LOG_DIR\"}"
  exit 1
fi

TAIL=$(docker exec "$CONTAINER" sh -c "tail -n 500 $LOG_DIR/$LOG_FILE" 2>/dev/null || true)
WARN_COUNT=$(printf "%s\n" "$TAIL" | grep -c " WARN " || true)
ERROR_COUNT=$(printf "%s\n" "$TAIL" | grep -c " ERROR " || true)
FATAL_COUNT=$(printf "%s\n" "$TAIL" | grep -c " FATAL " || true)
LAST_LINE=$(printf "%s" "$TAIL" | tail -n 1 | sed 's/"/\\"/g')

printf '{"status":"ok","broker_id":"%s","log_file":"%s","warn":%s,"error":%s,"fatal":%s,"last_line":"%s"}\n' \
  "$BROKER_ID" "$LOG_FILE" "$WARN_COUNT" "$ERROR_COUNT" "$FATAL_COUNT" "$LAST_LINE"
