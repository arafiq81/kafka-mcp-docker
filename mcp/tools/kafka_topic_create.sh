#!/bin/bash
# Create topic (write)
# Usage: kafka_topic_create.sh <topic> <partitions> <replication_factor>

set -e

. "$(cd "$(dirname "$0")" && pwd)/env.sh"
. "$(cd "$(dirname "$0")" && pwd)/guard.sh"

TOPIC="$1"
PARTITIONS="$2"
RF="$3"

# Normalize common flag-style args (e.g., --topic=foo, --partitions=3, --replication-factor=3)
for a in "$@"; do
  case "$a" in
    --topic=* )
      TOPIC="${a#--topic=}"
      ;;
    --partitions=* )
      PARTITIONS="${a#--partitions=}"
      ;;
    --replication-factor=* )
      RF="${a#--replication-factor=}"
      ;;
  esac
done

if [ -z "$TOPIC" ] || [ -z "$PARTITIONS" ] || [ -z "$RF" ]; then
  echo '{"status":"error","message":"usage: kafka_topic_create.sh <topic> <partitions> <replication_factor>"}'
  exit 1
fi

# If args are misordered or partial, try to recover
if ! echo "$PARTITIONS" | grep -Eq '^[0-9]+$' || ! echo "$RF" | grep -Eq '^[0-9]+$'; then
  # collect numeric tokens from all args
  NUMS=()
  for a in "$@"; do
    n=$(printf "%s" "$a" | grep -Eo '[0-9]+' | head -n1 || true)
    if [ -n "$n" ]; then
      NUMS+=("$n")
    fi
  done
  if [ ${#NUMS[@]} -ge 2 ]; then
    PARTITIONS="${NUMS[0]}"
    RF="${NUMS[1]}"
  fi

  # choose first non-numeric token as topic
  if ! echo "$TOPIC" | grep -Eq '^[0-9]+$'; then
    : # keep TOPIC
  else
    for a in "$@"; do
      if ! echo "$a" | grep -Eq '^[0-9]+$'; then
        TOPIC="$a"
        break
      fi
    done
  fi
fi

if ! echo "$PARTITIONS" | grep -Eq '^[0-9]+$' || ! echo "$RF" | grep -Eq '^[0-9]+$' || [ -z "$TOPIC" ]; then
  echo '{"status":"error","message":"invalid args: expected <topic> <partitions> <replication_factor>"}'
  exit 1
fi

require_write_allowed "kafka_topic_create"

if [ "$MCP_DRY_RUN" = "1" ]; then
  echo "{\"status\":\"ok\",\"dry_run\":true,\"command\":\"kafka-topics.sh --create --topic $TOPIC --partitions $PARTITIONS --replication-factor $RF\"}"
  exit 0
fi

OUT=$(docker exec "$KAFKA_CONTAINER" /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server "$KAFKA_BOOTSTRAP" \
  --command-config "$KAFKA_CLIENT_CFG" \
  --create --topic "$TOPIC" --partitions "$PARTITIONS" --replication-factor "$RF" 2>&1) || RC=$?
RC=${RC:-0}

if [ $RC -ne 0 ]; then
  ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
  audit_log "kafka_topic_create" "error" "$ESC" >> "$AUDIT_LOG"
  echo "{\"status\":\"error\",\"message\":\"$ESC\"}"
  exit $RC
fi

ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
audit_log "kafka_topic_create" "success" "$ESC" >> "$AUDIT_LOG"
printf '{"status":"ok","output":"%s"}\n' "$ESC"
