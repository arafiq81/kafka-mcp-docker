#!/bin/bash
# Read broker or topic configs (read-only)
# Usage: kafka_config_read.sh <broker|topic> <name> [--all]

set -e

. "$(cd "$(dirname "$0")" && pwd)/env.sh"

ENTITY_TYPE="$1"
ENTITY_NAME="$2"
MODE="$3"

if [ -z "$ENTITY_TYPE" ] || [ -z "$ENTITY_NAME" ]; then
  echo '{"status":"error","message":"usage: kafka_config_read.sh <broker|topic> <name> [--all]"}'
  exit 1
fi

if [ "$ENTITY_TYPE" = "broker" ]; then
  if [ "$MODE" = "--all" ]; then
    CMD=(/opt/kafka/bin/kafka-configs.sh --bootstrap-server "$KAFKA_BOOTSTRAP" --command-config "$KAFKA_CLIENT_CFG" --describe --entity-type brokers --entity-name "$ENTITY_NAME" --all)
  else
    CMD=(/opt/kafka/bin/kafka-configs.sh --bootstrap-server "$KAFKA_BOOTSTRAP" --command-config "$KAFKA_CLIENT_CFG" --describe --entity-type brokers --entity-name "$ENTITY_NAME")
  fi
elif [ "$ENTITY_TYPE" = "topic" ]; then
  if [ "$MODE" = "--all" ]; then
    CMD=(/opt/kafka/bin/kafka-configs.sh --bootstrap-server "$KAFKA_BOOTSTRAP" --command-config "$KAFKA_CLIENT_CFG" --describe --entity-type topics --entity-name "$ENTITY_NAME" --all)
  else
    CMD=(/opt/kafka/bin/kafka-configs.sh --bootstrap-server "$KAFKA_BOOTSTRAP" --command-config "$KAFKA_CLIENT_CFG" --describe --entity-type topics --entity-name "$ENTITY_NAME")
  fi
else
  echo '{"status":"error","message":"entity type must be broker or topic"}'
  exit 1
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
