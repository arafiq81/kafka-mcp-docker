#!/usr/bin/env python3
"""Minimal web UI server that bridges LM Studio API and MCP tools."""

import json
import os
import re
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse
import urllib.request
import urllib.error

LM_API = os.environ.get("LMSTUDIO_API", "http://127.0.0.1:1234/v1/chat/completions")
MCP_API = os.environ.get("MCP_API", "http://127.0.0.1:8088")
MODEL = os.environ.get("LMSTUDIO_MODEL", "local-model")
MCP_APPROVED_BY = os.environ.get("MCP_APPROVED_BY", "")
LAST_ERROR_TEXT = ""
LAST_TOOL_OUTPUT = ""

TOOL_LIST = [
    {"name": "kafka_topic_describe.sh", "display": "topic_describe", "description": "List all topics or describe a topic."},
    {"name": "kafka_consumer_group_describe.sh", "display": "consumer_group_describe", "description": "Describe consumer groups."},
    {"name": "kafka_broker_health.sh", "display": "broker_health", "description": "Broker log health summary."},
    {"name": "kafka_broker_status.sh", "display": "broker_status", "description": "Broker status and port check."},
    {"name": "kafka_logs_tail.sh", "display": "logs_tail", "description": "Tail broker logs."},
    {"name": "kafka_logs_tail_all.sh", "display": "logs_tail_all", "description": "Tail logs from all brokers."},
    {"name": "kafka_disk_health.sh", "display": "disk_health", "description": "Disk/log dir health."},
    {"name": "kafka_config_read.sh", "display": "config_read", "description": "Read effective configs."},
    {"name": "kafka_metrics_snapshot.sh", "display": "metrics_snapshot", "description": "JMX port check (POC)."},
    {"name": "kafka_tls_status.sh", "display": "tls_status", "description": "TLS cert expiry."},
    {"name": "kafka_isr_check.sh", "display": "isr_check", "description": "ISR health check."},
    {"name": "kafka_urp_report.sh", "display": "urp_report", "description": "Under-replicated partitions report."},
    {"name": "kafka_consumer_lag_snapshot.sh", "display": "consumer_lag_snapshot", "description": "Consumer lag snapshot (all groups)."},
    {"name": "kafka_health_dashboard.sh", "display": "health_dashboard", "description": "Combined health snapshot."},
    {"name": "kafka_topic_create.sh", "display": "topic_create", "description": "Create a topic."},
    {"name": "kafka_topic_delete.sh", "display": "topic_delete", "description": "Delete a topic."},
    {"name": "kafka_topic_alter_partitions.sh", "display": "topic_alter_partitions", "description": "Increase partitions."},
    {"name": "kafka_topic_alter_config.sh", "display": "topic_alter_config", "description": "Alter topic config."},
    {"name": "kafka_reassign_partitions.sh", "display": "reassign_partitions", "description": "Execute reassignment plan."},
    {"name": "kafka_preferred_leader_election.sh", "display": "preferred_leader_election", "description": "Preferred leader election."},
    {"name": "kafka_consumer_group_reset_offsets.sh", "display": "consumer_group_reset_offsets", "description": "Reset offsets."},
    {"name": "kafka_tls_rotate.sh", "display": "tls_rotate", "description": "TLS rotation (not implemented)."}
]

TOOL_NAMES = [t["name"] for t in TOOL_LIST]

SYSTEM = (
    "You are an ops assistant. Use ONLY the following tools: "
    + ", ".join(TOOL_NAMES)
    + ". If you need to use a tool, respond ONLY with JSON: "
    + "{\"tool\":\"tool_name\", \"args\":[...], \"env\":{...}}. "
    + "If no tool is needed, respond ONLY with JSON: {\"final\":\"...\"}. "
    + "Tool hints (natural phrasing supported): "
    + "\"show all topics\", \"list topics\", \"list topic names\" -> kafka_topic_describe.sh args [\"--all\"]; "
    + "\"describe topic X\", \"topic details X\" -> kafka_topic_describe.sh args [\"X\"]; "
    + "\"show consumer group X\", \"lag for group X\" -> kafka_consumer_group_describe.sh args [\"X\"]; "
    + "\"consumer lag snapshot\" -> kafka_consumer_lag_snapshot.sh args [\"--all\"]; "
    + "\"cluster health\", \"broker health\" -> kafka_broker_health.sh args [\"1\"]; "
    + "\"broker status\" -> kafka_broker_status.sh args [\"1\"]; "
    + "\"disk health\" -> kafka_disk_health.sh args [\"1\"]; "
    + "\"show logs of broker X\" -> kafka_logs_tail.sh args [\"X\",\"1000\"]; "
    + "\"kafka logs of broker X\" -> kafka_logs_tail.sh args [\"X\",\"1000\"]; "
    + "\"tail logs\", \"show broker 1 logs\" -> kafka_logs_tail.sh args [\"1\",\"50\"]; "
    + "\"show logs of all brokers\" -> kafka_logs_tail_all.sh args [\"1000\"]; "
    + "\"last 5 logs of all brokers\" -> kafka_logs_tail_all.sh args [\"5\"]; "
    + "\"errors in all brokers\" -> kafka_logs_tail_all.sh args [\"1000\",\"ERROR\"]; "
    + "\"search errors in logs\" -> kafka_logs_tail.sh args [\"1\",\"1000\",\"ERROR\"]; "
    + "\"search warnings in logs\" -> kafka_logs_tail.sh args [\"1\",\"1000\",\"WARN\"]; "
    + "\"search fatals in logs\" -> kafka_logs_tail.sh args [\"1\",\"1000\",\"FATAL\"]; "
    + "\"recent problems in logs\" -> kafka_logs_tail.sh args [\"1\",\"1000\",\"WARN\"]; "
    + "\"TLS expiry\", \"cert expiry\" -> kafka_tls_status.sh args [\"--all\"]; "
    + "\"ISR health\", \"under replicated partitions\" -> kafka_isr_check.sh args []; "
    + "\"health dashboard\" -> kafka_health_dashboard.sh args []; "
    + "\"under replicated partitions\" -> kafka_urp_report.sh args []; "
    + "\"read topic config X\" -> kafka_config_read.sh args [\"topic\",\"X\"]; "
    + "\"create topic X with 3 partitions rf 3\" -> kafka_topic_create.sh args [\"X\",\"3\",\"3\"]; "
    + "\"delete topic X\" -> kafka_topic_delete.sh args [\"X\"]; "
    + "\"increase partitions of X to 6\" -> kafka_topic_alter_partitions.sh args [\"X\",\"6\"]; "
    + "\"set retention.ms 600000 on X\" -> kafka_topic_alter_config.sh args [\"X\",\"retention.ms=600000\"]; "
    + "\"preferred leader election\" -> kafka_preferred_leader_election.sh args []; "
    + "\"reassign partitions\" -> kafka_reassign_partitions.sh args [\"/opt/kafka/config/reassign.json\"]."
)

WRITE_TOOLS = {"kafka_topic_create.sh","kafka_topic_delete.sh","kafka_topic_alter_partitions.sh","kafka_topic_alter_config.sh","kafka_reassign_partitions.sh","kafka_preferred_leader_election.sh","kafka_consumer_group_reset_offsets.sh","kafka_tls_rotate.sh"}


def http_post(url, payload):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        # Try to read JSON error body from MCP
        try:
            body = e.read().decode("utf-8")
            return json.loads(body)
        except Exception:
            raise


def call_lm(messages):
    payload = {"model": MODEL, "messages": messages, "temperature": 0.2}
    return http_post(LM_API, payload)


def call_mcp(tool, args, env):
    payload = {"args": args or [], "env": env or {}}
    return http_post(f"{MCP_API}/tool/{tool}", payload)


def redact(text: str) -> str:
    text = re.sub(r"\b(?:\d{1,3}\.){3}\d{1,3}\b", "<IP>", text)
    text = re.sub(r"\b[a-zA-Z0-9.-]+\.(local|internal|corp|com|net)\b", "<HOST>", text)
    text = re.sub(r"/(?:[^\s]+/)+[^\s]+", "<PATH>", text)
    return text


def _extract_topic_names(output: str):
    names = []
    seen = set()
    for line in output.splitlines():
        line = line.strip()
        if not line.startswith("Topic:"):
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        name = parts[1].strip()
        if name not in seen:
            seen.add(name)
            names.append(name)
    return names


def format_tool_output(tool: str, mcp_resp, args=None, prompt=""):
    # Default: return raw output/message
    if isinstance(mcp_resp, dict) and mcp_resp.get("status") == "error":
        return f"Error: {mcp_resp.get('message','')}"
    output = ""
    if isinstance(mcp_resp, dict):
        output = mcp_resp.get("output", "")
    if not output and isinstance(mcp_resp, str):
        output = mcp_resp

    # Try to parse nested JSON output
    try:
        parsed = json.loads(output)
    except Exception:
        parsed = None

    if tool == "kafka_topic_describe.sh":
        # Parse describe output into a summary
        lines = output.splitlines()
        if not lines:
            return "No topic information returned."
        if args is None:
            args = []
        if args == ["--all"] or args == ["--list"]:
            names = _extract_topic_names(output)
            if not names:
                return "No topics found."
            return "Topics:\n- " + "\n- ".join(names)
        # First line has topic summary
        header = lines[0]
        parts = [l for l in lines if "Partition:" in l]
        summary = [header]
        if parts:
            summary.append("Partitions:")
            for p in parts:
                summary.append("  " + p.strip())
        return "\n".join(summary)

    if tool == "kafka_logs_tail.sh" or tool == "kafka_logs_tail_all.sh":
        lines = output.splitlines()
        if not lines:
            return "No log lines returned."
        return "Recent log lines:\n" + "\n".join(lines[-50:])
    if tool == "kafka_consumer_lag_snapshot.sh":
        lines = output.splitlines()
        if not lines:
            return "No consumer lag data."
        return "Consumer lag snapshot:\n" + "\n".join(lines[:50])
    if tool == "kafka_urp_report.sh":
        if not output.strip():
            return "No under-replicated partitions."
        return "Under-replicated partitions:\n" + output
    if tool == "kafka_disk_health.sh":
        return "Disk health:\n" + output
    if tool == "kafka_broker_status.sh":
        return output

    if tool == "kafka_tls_status.sh" and parsed:
        items = parsed.get("results", [])
        if not items:
            return "No TLS status data."
        return "TLS expiry:\n" + "\n".join(
            [f"- {i.get('broker')}: {i.get('not_after')}" for i in items]
        )

    if tool == "kafka_isr_check.sh" and parsed:
        count = parsed.get("count", 0)
        if count == 0:
            return "ISR healthy: no under-replicated partitions."
        lines = ["Under-replicated partitions:"]
        # Prefer summary if present
        summary = parsed.get("summary", [])
        if summary:
            for s in summary:
                t = s.get("topic")
                parts = s.get("under_replicated_partitions", [])
                lines.append(f"- {t}: partitions {parts}")
        else:
            for it in parsed.get("under_replicated", []):
                t = it.get("topic")
                p = it.get("partition")
                if t is None or p is None:
                    continue
                lines.append(f"- {t}:{p}")
        return "\n".join(lines)

    if tool == "kafka_broker_health.sh" and parsed:
        return (
            f"Broker {parsed.get('broker_id')} health: "
            f"WARN={parsed.get('warn')} ERROR={parsed.get('error')} FATAL={parsed.get('fatal')}"
        )

    if tool == "kafka_topic_create.sh":
        # Friendly message for invalid replication factor
        if "InvalidReplicationFactorException" in output or "replication factor" in output:
            return (
                "Create topic failed: replication factor is higher than available brokers. "
                "Use RF <= number of brokers (for this cluster, max 3)."
            )
        return output or "No output."

    if tool == "kafka_health_dashboard.sh" and parsed:
        summ = parsed.get("summary", {})
        return (
            f"Health summary: ISR under-replicated={summ.get('isr_under_replicated')}, "
            f"TLS brokers={summ.get('tls_brokers')}. "
            f"Brokers: {', '.join(summ.get('brokers', []))}"
        )

    # Fallback: return output
    return output or "No output."


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, payload, ctype="application/json"):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/":
            with open(os.path.join(os.path.dirname(__file__), "index.html"), "rb") as f:
                body = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if parsed.path == "/logo":
            logo_path = "/tmp/Vodafone-Logo.jpg"
            if os.path.isfile(logo_path):
                with open(logo_path, "rb") as f:
                    body = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "image/jpeg")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            self._send(404, {"status": "error", "message": "logo not found"})
            return
        if parsed.path == "/tools":
            self._send(200, {"tools": TOOL_LIST})
            return
        if parsed.path == "/clusters":
            with open(os.path.join(os.path.dirname(__file__), "clusters.json"), "r") as f:
                data = json.load(f)
            self._send(200, data)
            return
        self._send(404, {"status": "error", "message": "not found"})

    def do_POST(self):
        global LAST_ERROR_TEXT
        global LAST_TOOL_OUTPUT
        parsed = urlparse(self.path)
        if parsed.path not in {"/chat", "/explain", "/approve", "/health"}:
            self._send(404, {"status": "error", "message": "not found"})
            return
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8") if length > 0 else "{}"
        try:
            payload = json.loads(raw)
        except Exception:
            self._send(400, {"status": "error", "message": "invalid JSON"})
            return

        if parsed.path == "/approve":
            tool = payload.get("tool")
            args = payload.get("args", [])
            env = payload.get("env", {})
            if MCP_APPROVED_BY:
                env["MCP_APPROVED_BY"] = MCP_APPROVED_BY
            try:
                mcp_resp = call_mcp(tool, args, env)
            except Exception as e:
                self._send(500, {"status": "error", "message": f"MCP error: {e}"})
                return
            error_text = ""
            if isinstance(mcp_resp, dict) and mcp_resp.get("status") == "error":
                error_text = mcp_resp.get("message", "")
                LAST_ERROR_TEXT = error_text
            else:
                LAST_TOOL_OUTPUT = json.dumps(mcp_resp)
            pretty = format_tool_output(tool, mcp_resp, args=args)
            self._send(200, {"reply": pretty, "tool_call": {"tool": tool, "args": args, "env": env}, "error_text": error_text})
            return

        if parsed.path == "/health":
            cluster = payload.get("cluster", "")
            env = {}
            if MCP_APPROVED_BY:
                env["MCP_APPROVED_BY"] = MCP_APPROVED_BY
            if cluster:
                env["KAFKA_CLUSTER_ID"] = cluster
            try:
                mcp_resp = call_mcp("kafka_health_dashboard.sh", [], env)
            except Exception as e:
                self._send(500, {"status": "error", "message": f"MCP error: {e}"})
                return
            # Summarize from JSON if possible
            summary = ""
            try:
                data = mcp_resp
                if isinstance(mcp_resp, dict) and "output" in mcp_resp:
                    data = json.loads(mcp_resp["output"])
                if isinstance(data, dict) and "summary" in data:
                    s = data["summary"]
                    summary = f"ISR under-replicated: {s.get('isr_under_replicated')} | TLS brokers: {s.get('tls_brokers')}"
            except Exception:
                pass
            pretty = format_tool_output("kafka_health_dashboard.sh", mcp_resp)
            self._send(200, {"reply": pretty, "summary": summary})
            return

        if parsed.path == "/explain":
            err = payload.get("error", "") or LAST_ERROR_TEXT or LAST_TOOL_OUTPUT
            if not err:
                self._send(200, {"reply": "According to Asif, no recent error to explain."})
                return
            red = redact(err)
            messages = [
                {"role": "system", "content": "Explain the Kafka error and suggest safe next steps."},
                {"role": "user", "content": red},
            ]
            try:
                resp = call_lm(messages)
            except Exception as e:
                self._send(500, {"status": "error", "message": f"LM error: {e}"})
                return
            if not isinstance(resp, dict) or "choices" not in resp:
                self._send(500, {"status": "error", "message": f"LM response missing choices: {resp}"})
                return
            content = resp["choices"][0]["message"]["content"].strip()
            self._send(200, {"reply": "According to Asif, " + content})
            return

        prompt = payload.get("prompt", "")
        cluster = payload.get("cluster", "")
        tool_mode = True
        llm_only = False
        if prompt.strip().lower().startswith("@llm") or prompt.strip().lower().startswith("@asif"):
            llm_only = True
            prompt = re.sub(r"^@\\w+\\s*", "", prompt.strip(), flags=re.I)
        if prompt.strip().lower() == "/help":
            self._send(200, {"reply": (
                "Examples:\n"
                "- List all topics\n"
                "- List topic names\n"
                "- Describe topic test-rf3\n"
                "- Check ISR health\n"
                "- Tail broker 1 logs last 50\n"
                "- Create topic demo with 3 partitions and RF 3\n"
                "\nTo force a tool call:\n"
                "Use tool kafka_topic_create.sh with args [\"demo\",\"3\",\"3\"]"
            )})
            return

        # Direct intent: list topic names only
        if re.search(r"\b(topic names|names of topics|list topic names|only topic names)\b", prompt, re.I):
            env = {}
            if MCP_APPROVED_BY:
                env["MCP_APPROVED_BY"] = MCP_APPROVED_BY
            if cluster:
                env["KAFKA_CLUSTER_ID"] = cluster
            try:
                mcp_resp = call_mcp("kafka_topic_describe.sh", ["--all"], env)
            except Exception as e:
                self._send(500, {"status": "error", "message": f"MCP error: {e}"})
                return
            pretty = format_tool_output("kafka_topic_describe.sh", mcp_resp, args=["--all"])
            self._send(200, {"reply": "According to Asif, " + pretty, "tool_call": {"tool": "kafka_topic_describe.sh", "args": ["--all"], "env": env}})
            return

        # If user asks for reason/clarification of error, answer using last error or last tool output
        if re.search(r"reason of (the )?error|what (was|is) the error|why did it fail|clarify the errors", prompt, re.I):
            err_text = LAST_ERROR_TEXT or LAST_TOOL_OUTPUT
            if err_text:
                red = redact(err_text)
                messages = [
                    {"role": "system", "content": "Explain the Kafka error and suggest safe next steps."},
                    {"role": "user", "content": red},
                ]
                try:
                    resp = call_lm(messages)
                except Exception as e:
                    self._send(500, {"status": "error", "message": f"LM error: {e}"})
                    return
                if not isinstance(resp, dict) or "choices" not in resp:
                    self._send(500, {"status": "error", "message": f"LM response missing choices: {resp}"})
                    return
                content = resp["choices"][0]["message"]["content"].strip()
                self._send(200, {"reply": "According to Asif, " + content})
                return

        # Direct intent: list errors across all brokers (last N mins)
        if re.search(r"errors?.*last\\s*\\d+\\s*min|errors?.*across all brokers|list.*errors.*brokers", prompt, re.I):
            minutes = 30
            m = re.search(r"last\\s*(\\d+)\\s*min", prompt, re.I)
            if m:
                minutes = int(m.group(1))
            # Approximate by tailing 1000 lines; filter ERROR
            env = {"KAFKA_CLUSTER_ID": cluster} if cluster else {}
            try:
                mcp_resp = call_mcp("kafka_logs_tail_all.sh", ["1000", "ERROR"], env)
            except Exception as e:
                self._send(500, {"status": "error", "message": f"MCP error: {e}"})
                return
            LAST_TOOL_OUTPUT = json.dumps(mcp_resp)
            pretty = format_tool_output("kafka_logs_tail_all.sh", mcp_resp)
            self._send(200, {"reply": "According to Asif, " + f"Errors (approx last {minutes} mins):\n" + pretty, "tool_call": {"tool": "kafka_logs_tail_all.sh", "args": ["1000","ERROR"], "env": env}})
            return

        if llm_only:
            messages = [
                {"role": "system", "content": "You are Asif. Answer in plain language. Do not call tools."},
                {"role": "user", "content": prompt},
            ]
            try:
                resp = call_lm(messages)
            except Exception as e:
                self._send(500, {"status": "error", "message": f"LM error: {e}"})
                return
            if not isinstance(resp, dict) or "choices" not in resp:
                self._send(500, {"status": "error", "message": f"LM response missing choices: {resp}"})
                return
            content = resp["choices"][0]["message"]["content"].strip()
            self._send(200, {"reply": "According to Asif, " + content})
            return

        messages = [
            {"role": "system", "content": SYSTEM},
            {"role": "user", "content": prompt},
        ]

        try:
            resp = call_lm(messages)
        except Exception as e:
            self._send(500, {"status": "error", "message": f"LM error: {e}"})
            return

        if not isinstance(resp, dict) or "choices" not in resp:
            self._send(500, {"status": "error", "message": f"LM response missing choices: {resp}"})
            return
        content = resp["choices"][0]["message"]["content"].strip()
        try:
            tool_req = json.loads(content)
        except Exception:
            self._send(200, {"reply": "According to Asif, " + content})
            return

        if "final" in tool_req:
            self._send(200, {"reply": "According to Asif, " + tool_req["final"]})
            return

        tool = tool_req.get("tool")
        args = tool_req.get("args", [])
        env = tool_req.get("env", {})

        if tool not in TOOL_NAMES:
            self._send(400, {"status": "error", "message": f"invalid tool: {tool}"})
            return

        if tool == "kafka_topic_describe.sh" and args == ["--list"]:
            args = ["--all"]

        if MCP_APPROVED_BY:
            env["MCP_APPROVED_BY"] = MCP_APPROVED_BY

        if cluster:
            env["KAFKA_CLUSTER_ID"] = cluster

        if tool in WRITE_TOOLS:
            self._send(200, {"pending_write": {"tool": tool, "args": args, "env": env}, "tool_call": {"tool": tool, "args": args, "env": env}})
            return

        try:
            mcp_resp = call_mcp(tool, args, env)
        except Exception as e:
            self._send(500, {"status": "error", "message": f"MCP error: {e}"})
            return

        error_text = ""
        if isinstance(mcp_resp, dict) and mcp_resp.get("status") == "error":
            error_text = mcp_resp.get("message", "")
        if error_text:
            LAST_ERROR_TEXT = error_text
        else:
            LAST_TOOL_OUTPUT = json.dumps(mcp_resp)

        messages.append({"role": "assistant", "content": content})
        messages.append({"role": "tool", "content": json.dumps(mcp_resp)})

        try:
            resp2 = call_lm(messages)
        except Exception as e:
            self._send(500, {"status": "error", "message": f"LM error: {e}"})
            return

        if not isinstance(resp2, dict) or "choices" not in resp2:
            self._send(500, {"status": "error", "message": f"LM response missing choices: {resp2}"})
            return
        content2 = resp2["choices"][0]["message"]["content"].strip()
        try:
            parsed2 = json.loads(content2)
            if isinstance(parsed2, dict) and "tool" in parsed2:
                content2 = json.dumps(mcp_resp)
        except Exception:
            pass

        pretty = format_tool_output(tool, mcp_resp, args=args, prompt=prompt)
        self._send(200, {"reply": "According to Asif, " + pretty, "tool_call": {"tool": tool, "args": args, "env": env}, "error_text": error_text})


def main():
    host = os.environ.get("WEBUI_HOST", "127.0.0.1")
    port = int(os.environ.get("WEBUI_PORT", "8090"))
    httpd = HTTPServer((host, port), Handler)
    print(f"Web UI running at http://{host}:{port}")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
