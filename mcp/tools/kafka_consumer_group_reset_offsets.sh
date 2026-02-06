#!/bin/bash
# Reset consumer group offsets (write)
# Usage: kafka_consumer_group_reset_offsets.sh <group> <topic> <to-earliest|to-latest>

set -e

. "$(cd "$(dirname "$0")" && pwd)/env.sh"
. "$(cd "$(dirname "$0")" && pwd)/guard.sh"

GROUP="$1"
TOPIC="$2"
MODE="$3"

if [ -z "$GROUP" ] || [ -z "$TOPIC" ] || [ -z "$MODE" ]; then
  echo '{"status":"error","message":"usage: kafka_consumer_group_reset_offsets.sh <group> <topic> <to-earliest|to-latest>"}'
  exit 1
fi

require_write_allowed "kafka_consumer_group_reset_offsets"

if [ "$MCP_DRY_RUN" = "1" ]; then
  echo "{\"status\":\"ok\",\"dry_run\":true,\"command\":\"kafka-consumer-groups.sh --group $GROUP --topic $TOPIC --reset-offsets --$MODE --execute\"}"
  exit 0
fi

OUT=$(docker exec "$KAFKA_CONTAINER" /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server "$KAFKA_BOOTSTRAP" \
  --command-config "$KAFKA_CLIENT_CFG" \
  --group "$GROUP" --topic "$TOPIC" --reset-offsets --$MODE --execute 2>&1) || RC=$?
RC=${RC:-0}

if [ $RC -ne 0 ]; then
  ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
  audit_log "kafka_consumer_group_reset_offsets" "error" "$ESC" >> "$AUDIT_LOG"
  echo "{\"status\":\"error\",\"message\":\"$ESC\"}"
  exit $RC
fi

ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
audit_log "kafka_consumer_group_reset_offsets" "success" "$ESC" >> "$AUDIT_LOG"
printf '{"status":"ok","output":"%s"}\n' "$ESC"
