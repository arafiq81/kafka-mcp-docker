#!/usr/bin/env python3
"""
LM Studio ↔ MCP Bridge (minimal)

- Sends user prompt to LM Studio API (OpenAI-compatible).
- Expects the model to return a JSON tool call or a final answer.
- Executes MCP tool if requested, then returns tool output to the model.

Configure:
  export LMSTUDIO_API=http://127.0.0.1:1234/v1/chat/completions
  export MCP_API=http://127.0.0.1:8088
  export MCP_APPROVED_BY=your-name
"""

import json
import os
import sys
import urllib.request

LM_API = os.environ.get("LMSTUDIO_API", "http://127.0.0.1:1234/v1/chat/completions")
MCP_API = os.environ.get("MCP_API", "http://127.0.0.1:8088")
MODEL = os.environ.get("LMSTUDIO_MODEL", "local-model")

TOOL_LIST = [
    "kafka_topic_describe.sh",
    "kafka_consumer_group_describe.sh",
    "kafka_broker_health.sh",
    "kafka_logs_tail.sh",
    "kafka_config_read.sh",
    "kafka_metrics_snapshot.sh",
    "kafka_tls_status.sh",
    "kafka_isr_check.sh",
    "kafka_topic_create.sh",
    "kafka_topic_delete.sh",
    "kafka_topic_alter_partitions.sh",
    "kafka_topic_alter_config.sh",
    "kafka_reassign_partitions.sh",
    "kafka_preferred_leader_election.sh",
    "kafka_consumer_group_reset_offsets.sh",
    "kafka_tls_rotate.sh",
]

SYSTEM = (
    "You are an ops assistant. Use ONLY the following tools: "
    + ", ".join(TOOL_LIST)
    + ". If you need to use a tool, respond ONLY with JSON: "
    + "{\"tool\":\"tool_name\", \"args\":[...], \"env\":{...}}. "
    + "If no tool is needed, respond ONLY with JSON: {\"final\":\"...\"}. "
    + "Tool hints (natural phrasing supported): "
    + "\"show all topics\", \"list topics\" -> kafka_topic_describe.sh args [\"--all\"]; "
    + "\"describe topic X\", \"topic details X\" -> kafka_topic_describe.sh args [\"X\"]; "
    + "\"show consumer group X\", \"lag for group X\" -> kafka_consumer_group_describe.sh args [\"X\"]; "
    + "\"cluster health\", \"broker health\" -> kafka_broker_health.sh args [\"1\"]; "
    + "\"tail logs\", \"show broker 1 logs\" -> kafka_logs_tail.sh args [\"1\",\"50\"]; "
    + "\"TLS expiry\", \"cert expiry\" -> kafka_tls_status.sh args [\"--all\"]; "
    + "\"ISR health\", \"under replicated partitions\" -> kafka_isr_check.sh args []; "
    + "\"read topic config X\" -> kafka_config_read.sh args [\"topic\",\"X\"]; "
    + "\"create topic X with 3 partitions rf 3\" -> kafka_topic_create.sh args [\"X\",\"3\",\"3\"]; "
    + "\"delete topic X\" -> kafka_topic_delete.sh args [\"X\"]; "
    + "\"increase partitions of X to 6\" -> kafka_topic_alter_partitions.sh args [\"X\",\"6\"]; "
    + "\"set retention.ms 600000 on X\" -> kafka_topic_alter_config.sh args [\"X\",\"retention.ms=600000\"]; "
    + "\"preferred leader election\" -> kafka_preferred_leader_election.sh args []; "
    + "\"reassign partitions\" -> kafka_reassign_partitions.sh args [\"/opt/kafka/config/reassign.json\"]."
)


def http_post(url, payload):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))


def call_lm(messages):
    payload = {
        "model": MODEL,
        "messages": messages,
        "temperature": 0.2,
    }
    return http_post(LM_API, payload)


def call_mcp(tool, args, env):
    payload = {"args": args or [], "env": env or {}}
    return http_post(f"{MCP_API}/tool/{tool}", payload)


def main():
    if len(sys.argv) < 2:
        print("Usage: lmstudio-mcp-bridge.py <prompt>")
        sys.exit(1)

    user_prompt = " ".join(sys.argv[1:])
    messages = [
        {"role": "system", "content": SYSTEM},
        {"role": "user", "content": user_prompt},
    ]

    resp = call_lm(messages)
    content = resp["choices"][0]["message"]["content"].strip()

    try:
        tool_req = json.loads(content)
    except Exception:
        print("Model did not return valid JSON. Raw content:")
        print(content)
        sys.exit(1)

    if "final" in tool_req:
        print(tool_req["final"])
        return

    tool = tool_req.get("tool")
    args = tool_req.get("args", [])
    env = tool_req.get("env", {})

    # Always pass approval identity if set
    if os.environ.get("MCP_APPROVED_BY"):
        env["MCP_APPROVED_BY"] = os.environ["MCP_APPROVED_BY"]

    if tool not in TOOL_LIST:
        print(f"Invalid tool requested by model: {tool}")
        print("Allowed tools:", ", ".join(TOOL_LIST))
        sys.exit(1)

    # Normalize common mistakes
    if tool == "kafka_topic_describe.sh" and args == ["--list"]:
        args = ["--all"]

    mcp_resp = call_mcp(tool, args, env)

    # Send tool output back to model for final response
    messages.append({"role": "assistant", "content": content})
    messages.append({"role": "tool", "content": json.dumps(mcp_resp)})

    resp2 = call_lm(messages)
    content2 = resp2["choices"][0]["message"]["content"].strip()
    print(content2)


if __name__ == "__main__":
    main()
