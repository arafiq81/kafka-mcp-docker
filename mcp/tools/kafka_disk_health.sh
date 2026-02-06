#!/bin/bash
# Disk/log dir health (read-only)
# Usage: kafka_disk_health.sh <broker_id>

set -e

BROKER_ID="$1"
if [ -z "$BROKER_ID" ]; then
  echo '{"status":"error","message":"broker_id is required"}'
  exit 1
fi

CONTAINER="kafka${BROKER_ID}"
DATA_DIR="/var/lib/kafka"

OUT=$(docker exec "$CONTAINER" sh -c "df -h $DATA_DIR && du -sh $DATA_DIR" 2>&1) || RC=$?
RC=${RC:-0}

if [ $RC -ne 0 ]; then
  ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
  echo "{\"status\":\"error\",\"message\":\"$ESC\"}"
  exit $RC
fi

ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
printf '{"status":"ok","output":"%s"}\n' "$ESC"
