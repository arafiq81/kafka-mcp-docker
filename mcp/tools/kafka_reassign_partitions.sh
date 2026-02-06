#!/bin/bash
# Execute partition reassignment (write)
# Usage: kafka_reassign_partitions.sh <reassign_json_path_in_container>

set -e

. "$(cd "$(dirname "$0")" && pwd)/env.sh"
. "$(cd "$(dirname "$0")" && pwd)/guard.sh"

PLAN_PATH="$1"
if [ -z "$PLAN_PATH" ]; then
  echo '{"status":"error","message":"usage: kafka_reassign_partitions.sh <reassign_json_path_in_container>"}'
  exit 1
fi

require_write_allowed "kafka_reassign_partitions"

if [ "$MCP_DRY_RUN" = "1" ]; then
  echo "{\"status\":\"ok\",\"dry_run\":true,\"command\":\"kafka-reassign-partitions.sh --reassignment-json-file $PLAN_PATH --execute\"}"
  exit 0
fi

OUT=$(docker exec "$KAFKA_CONTAINER" /opt/kafka/bin/kafka-reassign-partitions.sh \
  --bootstrap-server "$KAFKA_BOOTSTRAP" \
  --command-config "$KAFKA_CLIENT_CFG" \
  --reassignment-json-file "$PLAN_PATH" --execute 2>&1) || RC=$?
RC=${RC:-0}

if [ $RC -ne 0 ]; then
  ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
  audit_log "kafka_reassign_partitions" "error" "$ESC" >> "$AUDIT_LOG"
  echo "{\"status\":\"error\",\"message\":\"$ESC\"}"
  exit $RC
fi

ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
audit_log "kafka_reassign_partitions" "success" "$ESC" >> "$AUDIT_LOG"
printf '{"status":"ok","output":"%s"}\n' "$ESC"
