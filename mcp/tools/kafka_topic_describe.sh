#!/bin/bash
# Describe Kafka topics using docker exec (read-only).
# Usage: kafka_topic_describe.sh <topic|--all>

set -e

. "$(cd "$(dirname "$0")" && pwd)/env.sh"

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo '{"status":"error","message":"topic name or --all required"}'
  exit 1
fi

if [ "$TARGET" = "--all" ]; then
  CMD=(/opt/kafka/bin/kafka-topics.sh --bootstrap-server "$KAFKA_BOOTSTRAP" --command-config "$KAFKA_CLIENT_CFG" --describe)
else
  CMD=(/opt/kafka/bin/kafka-topics.sh --bootstrap-server "$KAFKA_BOOTSTRAP" --command-config "$KAFKA_CLIENT_CFG" --describe --topic "$TARGET")
fi

OUT=$(docker exec "$KAFKA_CONTAINER" "${CMD[@]}" 2>&1) || RC=$?
RC=${RC:-0}

if [ $RC -ne 0 ]; then
  ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
  echo "{\"status\":\"error\",\"message\":\"$ESC\"}"
  exit $RC
fi

ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
printf '{"status":"ok","output":"%s"}\n' "$ESC"
