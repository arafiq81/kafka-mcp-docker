#!/bin/bash
# Consumer lag snapshot (read-only)
# Usage: kafka_consumer_lag_snapshot.sh [--all|<group>]

set -e

. "$(cd "$(dirname "$0")" && pwd)/env.sh"

TARGET="$1"
if [ -z "$TARGET" ]; then
  TARGET="--all"
fi

if [ "$TARGET" = "--all" ]; then
  CMD=(/opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server "$KAFKA_BOOTSTRAP" --command-config "$KAFKA_CLIENT_CFG" --all-groups --describe)
else
  CMD=(/opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server "$KAFKA_BOOTSTRAP" --command-config "$KAFKA_CLIENT_CFG" --group "$TARGET" --describe)
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
