#!/bin/bash
# Combined health snapshot (read-only)
# Usage: kafka_health_dashboard.sh [--text]

set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
MODE="$1"

export TOPICS=$($ROOT/kafka_topic_describe.sh --all 2>/dev/null || true)
export ISR=$($ROOT/kafka_isr_check.sh 2>/dev/null || true)
export B1=$($ROOT/kafka_broker_health.sh 1 2>/dev/null || true)
export B2=$($ROOT/kafka_broker_health.sh 2 2>/dev/null || true)
export B3=$($ROOT/kafka_broker_health.sh 3 2>/dev/null || true)
export TLS=$($ROOT/kafka_tls_status.sh --all 2>/dev/null || true)

python3 - <<PY
import json
import os

def safe_load(s):
    try:
        return json.loads(s)
    except Exception:
        return {"status":"error","raw":s}

out = {
  "status":"ok",
  "isr": safe_load(os.environ.get("ISR","")),
  "broker_health": [safe_load(os.environ.get("B1","")), safe_load(os.environ.get("B2","")), safe_load(os.environ.get("B3",""))],
  "tls": safe_load(os.environ.get("TLS","")),
  "topics": safe_load(os.environ.get("TOPICS",""))
}

# Build a simple human-readable summary
def brk_summary(b):
    if b.get("status") != "ok":
        return "broker: error"
    return f"broker {b.get('broker_id')}: warn={b.get('warn')} error={b.get('error')} fatal={b.get('fatal')}"

isr_count = out.get("isr", {}).get("count", "unknown")
tls_count = len(out.get("tls", {}).get("results", [])) if isinstance(out.get("tls"), dict) else 0

summary = {
  "isr_under_replicated": isr_count,
  "brokers": [brk_summary(b) for b in out.get("broker_health", [])],
  "tls_brokers": tls_count
}

if "${MODE:-}" == "--text":
    print("Kafka Health Dashboard")
    print("======================")
    print(f"ISR under-replicated partitions: {summary['isr_under_replicated']}")
    print("Broker health:")
    for line in summary["brokers"]:
        print(f"- {line}")
    print(f"TLS brokers checked: {summary['tls_brokers']}")
else:
    print(json.dumps({"summary": summary, "details": out}))
PY
