#!/bin/bash
# Check ISR health by counting under-replicated partitions.
# Usage: kafka_isr_check.sh

set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"

python3 - <<PY
import json,subprocess,sys,re
cmd=["$ROOT/kafka_urp_report.sh"]
try:
    raw=subprocess.check_output(cmd, text=True)
except Exception:
    raw=""
lines=[]
try:
    data=json.loads(raw)
    out=data.get("output","")
    lines=[l for l in out.splitlines() if "Topic:" in l]
except Exception:
    lines=[l for l in raw.splitlines() if "Topic:" in l]

items=[]
by_topic={}
for l in lines:
    m=re.search(r"Topic:\s*(\S+)\s+Partition:\s*(\d+).*Replicas:\s*([^ ]+)\s+Isr:\s*([^ ]+)", l)
    if m:
        topic, part, replicas, isr = m.group(1), int(m.group(2)), m.group(3), m.group(4)
        by_topic.setdefault(topic, []).append(part)
        items.append({"topic": topic, "partition": part, "replicas": replicas, "isr": isr})
    else:
        items.append({"raw": l.strip()})

summary=[]
for t, parts in sorted(by_topic.items()):
    summary.append({"topic": t, "under_replicated_partitions": sorted(parts), "count": len(parts)})

print(json.dumps({"status":"ok","count": len(items), "summary": summary, "under_replicated": items}))
PY
