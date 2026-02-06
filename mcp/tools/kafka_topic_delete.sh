#!/bin/bash
# Delete topic (write)
# Usage: kafka_topic_delete.sh <topic>

set -e

. "$(cd "$(dirname "$0")" && pwd)/env.sh"
. "$(cd "$(dirname "$0")" && pwd)/guard.sh"

TOPIC="$1"
if [ -z "$TOPIC" ]; then
  echo '{"status":"error","message":"usage: kafka_topic_delete.sh <topic>"}'
  exit 1
fi

require_write_allowed "kafka_topic_delete"

if [ "$MCP_DRY_RUN" = "1" ]; then
  echo "{\"status\":\"ok\",\"dry_run\":true,\"command\":\"kafka-topics.sh --delete --topic $TOPIC\"}"
  exit 0
fi

OUT=$(docker exec "$KAFKA_CONTAINER" /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server "$KAFKA_BOOTSTRAP" \
  --command-config "$KAFKA_CLIENT_CFG" \
  --delete --topic "$TOPIC" 2>&1) || RC=$?
RC=${RC:-0}

if [ $RC -ne 0 ]; then
  ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
  audit_log "kafka_topic_delete" "error" "$ESC" >> "$AUDIT_LOG"
  echo "{\"status\":\"error\",\"message\":\"$ESC\"}"
  exit $RC
fi

ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
audit_log "kafka_topic_delete" "success" "$ESC" >> "$AUDIT_LOG"
printf '{"status":"ok","output":"%s"}\n' "$ESC"
