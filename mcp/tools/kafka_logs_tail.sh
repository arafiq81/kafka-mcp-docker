#!/bin/bash
# Tail broker logs from container logs directory.
# Usage: kafka_logs_tail.sh <broker_id> <lines> [WARN|ERROR|FATAL|INFO]

set -e

BROKER_ID="$1"
LINES="$2"
LEVEL="$3"

if [ -z "$BROKER_ID" ]; then
  echo '{"status":"error","message":"broker_id is required"}'
  exit 1
fi

if [ -z "$LINES" ]; then
  LINES=200
fi

CONTAINER="kafka${BROKER_ID}"
LOG_DIR="/opt/kafka/logs"

# Prefer server.log; fall back to first *.log
LOG_FILE=$(docker exec "$CONTAINER" sh -c "ls -1 $LOG_DIR 2>/dev/null | grep -m1 '^server\\.log$' || ls -1 $LOG_DIR/*.log 2>/dev/null | head -n1" || true)

if [ -z "$LOG_FILE" ]; then
  echo "{\"status\":\"error\",\"message\":\"no log file found in $LOG_DIR\"}"
  exit 1
fi

if echo "$LOG_FILE" | grep -q "/"; then
  LOG_PATH="$LOG_FILE"
else
  LOG_PATH="$LOG_DIR/$LOG_FILE"
fi

OUT=$(docker logs "$CONTAINER" --tail "$LINES" 2>&1 || true)

if [ -n "$LEVEL" ]; then
  OUT=$(printf "%s\n" "$OUT" | grep " $LEVEL " || true)
fi

# Convert output to JSON array of lines safely
JSON_LINES=$(python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().splitlines()))' <<<"$OUT")

printf '{"status":"ok","lines":%s}\n' "$JSON_LINES"
