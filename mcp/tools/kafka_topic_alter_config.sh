#!/bin/bash
# Alter topic configs (write)
# Usage: kafka_topic_alter_config.sh <topic> <key=value> [<key=value> ...]

set -e

. "$(cd "$(dirname "$0")" && pwd)/env.sh"
. "$(cd "$(dirname "$0")" && pwd)/guard.sh"

TOPIC="$1"
shift || true

if [ -z "$TOPIC" ] || [ "$#" -lt 1 ]; then
  echo '{"status":"error","message":"usage: kafka_topic_alter_config.sh <topic> <key=value> [<key=value> ...]"}'
  exit 1
fi

# Guard: partitions must be changed via kafka_topic_alter_partitions.sh
for kv in "$@"; do
  case "$kv" in
    partitions=*|*partitions=*|--partitions*|--topic*|topic=*)
      echo '{"status":"error","message":"invalid args: partitions must be changed via topic_alter_partitions"}'
      exit 1
      ;;
  esac
done

require_write_allowed "kafka_topic_alter_config"

ADD_CONFIG=$(printf '%s,' "$@" | sed 's/,$//')

if [ "$MCP_DRY_RUN" = "1" ]; then
  echo "{\"status\":\"ok\",\"dry_run\":true,\"command\":\"kafka-configs.sh --alter --entity-type topics --entity-name $TOPIC --add-config $ADD_CONFIG\"}"
  exit 0
fi

OUT=$(docker exec "$KAFKA_CONTAINER" /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server "$KAFKA_BOOTSTRAP" \
  --command-config "$KAFKA_CLIENT_CFG" \
  --alter --entity-type topics --entity-name "$TOPIC" \
  --add-config "$ADD_CONFIG" 2>&1) || RC=$?
RC=${RC:-0}

if [ $RC -ne 0 ]; then
  ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
  audit_log "kafka_topic_alter_config" "error" "$ESC" >> "$AUDIT_LOG"
  echo "{\"status\":\"error\",\"message\":\"$ESC\"}"
  exit $RC
fi

ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
audit_log "kafka_topic_alter_config" "success" "$ESC" >> "$AUDIT_LOG"
printf '{"status":"ok","output":"%s"}\n' "$ESC"
