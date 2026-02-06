#!/bin/bash
# Preferred leader election (write)
# Usage: kafka_preferred_leader_election.sh

set -e

. "$(cd "$(dirname "$0")" && pwd)/env.sh"
. "$(cd "$(dirname "$0")" && pwd)/guard.sh"

require_write_allowed "kafka_preferred_leader_election"

if [ "$MCP_DRY_RUN" = "1" ]; then
  echo "{\"status\":\"ok\",\"dry_run\":true,\"command\":\"kafka-preferred-replica-election.sh\"}"
  exit 0
fi

OUT=$(docker exec "$KAFKA_CONTAINER" /opt/kafka/bin/kafka-preferred-replica-election.sh \
  --bootstrap-server "$KAFKA_BOOTSTRAP" \
  --command-config "$KAFKA_CLIENT_CFG" 2>&1) || RC=$?
RC=${RC:-0}

if [ $RC -ne 0 ]; then
  ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
  audit_log "kafka_preferred_leader_election" "error" "$ESC" >> "$AUDIT_LOG"
  echo "{\"status\":\"error\",\"message\":\"$ESC\"}"
  exit $RC
fi

ESC=$(printf "%s" "$OUT" | sed 's/"/\\"/g')
audit_log "kafka_preferred_leader_election" "success" "$ESC" >> "$AUDIT_LOG"
printf '{"status":"ok","output":"%s"}\n' "$ESC"
