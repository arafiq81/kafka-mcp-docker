#!/bin/bash
# Under-replicated partitions report (read-only)
# Usage: kafka_urp_report.sh

set -e

. "$(cd "$(dirname "$0")" && pwd)/env.sh"

OUT=$(docker exec "$KAFKA_CONTAINER" /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server "$KAFKA_BOOTSTRAP" \
  --command-config "$KAFKA_CLIENT_CFG" \
  --describe --under-replicated-partitions 2>&1) || RC=$?
RC=${RC:-0}

if [ $RC -ne 0 ]; then
  ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
  echo "{\"status\":\"error\",\"message\":\"$ESC\"}"
  exit $RC
fi

ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
printf '{"status":"ok","output":"%s"}\n' "$ESC"
