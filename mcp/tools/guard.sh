#!/bin/bash
# Common guard for write tools

set -e

POLICY_FILE="${MCP_POLICY_FILE:-$(cd "$(dirname "$0")/.." && pwd)/policy/policy.yaml}"
AUDIT_LOG="${MCP_AUDIT_LOG:-$(cd "$(dirname "$0")/.." && pwd)/audit.log}"

require_approval() {
  if [ -z "$MCP_APPROVED_BY" ]; then
    echo '{"status":"error","message":"approval required: set MCP_APPROVED_BY=<name>"}'
    exit 1
  fi
}

audit_log() {
  local tool="$1"
  local status="$2"
  local message="$3"
  python3 -W ignore -c 'import json,datetime,sys; tool=sys.argv[1]; status=sys.argv[2]; msg=sys.argv[3]; entry={"ts": datetime.datetime.now(datetime.timezone.utc).isoformat(),"tool": tool,"status": status,"by": sys.argv[4],"message": msg}; print(json.dumps(entry))' \
    "$tool" "$status" "$message" "${MCP_APPROVED_BY:-}"
}

maintenance_lock_enabled() {
  grep -q '^maintenance_lock: true' "$POLICY_FILE"
}

is_allowed_during_maintenance() {
  local tool="$1"
  awk '/maintenance_exceptions:/,0' "$POLICY_FILE" | awk '/allow:/,0' | grep -q "- $tool"
}

require_write_allowed() {
  local tool="$1"
  if maintenance_lock_enabled; then
    if ! is_allowed_during_maintenance "$tool"; then
      echo '{"status":"error","message":"write blocked: maintenance_lock enabled"}'
      audit_log "$tool" "blocked" "maintenance_lock enabled" >> "$AUDIT_LOG"
      exit 1
    fi
  fi
  require_approval
  # Health check gate: block if ISR < RF anywhere
  if [ -x "$(cd "$(dirname "$0")" && pwd)/kafka_isr_check.sh" ]; then
    local check
    check=$("$(cd "$(dirname "$0")" && pwd)/kafka_isr_check.sh" 2>/dev/null || true)
    if [ -n "$check" ]; then
      echo "$check" | python3 - <<'PY'
import json,sys
try:
    data=json.loads(sys.stdin.read())
    sys.exit(1 if data.get("count",0) > 0 else 0)
except Exception:
    # If output isn't valid JSON, don't block writes
    sys.exit(0)
PY
      if [ $? -eq 1 ]; then
        echo '{"status":"error","message":"write blocked: ISR under-replication detected"}'
        audit_log "$tool" "blocked" "ISR under-replication detected" >> "$AUDIT_LOG"
        exit 1
      fi
    fi
  fi
  audit_log "$tool" "allowed" "write permitted" >> "$AUDIT_LOG"
}
