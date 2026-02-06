#!/bin/bash
# Increase partitions (write)
# Usage: kafka_topic_alter_partitions.sh <topic> <new_partition_count>

set -e

. "$(cd "$(dirname "$0")" && pwd)/env.sh"
. "$(cd "$(dirname "$0")" && pwd)/guard.sh"

TOPIC="$1"
NEW_COUNT="$2"

if [ -z "$TOPIC" ] || [ -z "$NEW_COUNT" ]; then
  echo '{"status":"error","message":"usage: kafka_topic_alter_partitions.sh <topic> <new_partition_count>"}'
  exit 1
fi

require_write_allowed "kafka_topic_alter_partitions"

if [ "$MCP_DRY_RUN" = "1" ]; then
  echo "{\"status\":\"ok\",\"dry_run\":true,\"command\":\"kafka-topics.sh --alter --topic $TOPIC --partitions $NEW_COUNT\"}"
  exit 0
fi

OUT=$(docker exec "$KAFKA_CONTAINER" /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server "$KAFKA_BOOTSTRAP" \
  --command-config "$KAFKA_CLIENT_CFG" \
  --alter --topic "$TOPIC" --partitions "$NEW_COUNT" 2>&1) || RC=$?
RC=${RC:-0}

if [ $RC -ne 0 ]; then
  ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
  audit_log "kafka_topic_alter_partitions" "error" "$ESC" >> "$AUDIT_LOG"
  echo "{\"status\":\"error\",\"message\":\"$ESC\"}"
  exit $RC
fi

ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
audit_log "kafka_topic_alter_partitions" "success" "$ESC" >> "$AUDIT_LOG"
printf '{"status":"ok","output":"%s"}\n' "$ESC"
