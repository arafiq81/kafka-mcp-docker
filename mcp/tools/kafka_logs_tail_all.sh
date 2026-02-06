#!/bin/bash
# Tail logs from all brokers (read-only)
# Usage: kafka_logs_tail_all.sh <lines> [WARN|ERROR|FATAL|INFO]

set -e

LINES="$1"
LEVEL="$2"

if [ -z "$LINES" ]; then
  LINES=200
fi

for b in 1 2 3; do
  OUT=$(docker logs "kafka${b}" --tail "$LINES" 2>&1 || true)
  if [ -n "$LEVEL" ]; then
    OUT=$(printf "%s\n" "$OUT" | grep " $LEVEL " || true)
  fi
  echo "=== broker ${b} ==="
  if [ -n "$OUT" ]; then
    echo "$OUT"
  else
    echo "<no lines>"
  fi
  echo
 done
