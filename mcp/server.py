#!/usr/bin/env python3
"""
Minimal MCP-style tool gateway (HTTP JSON).
- GET /tools -> list tools
- POST /tool/<name> with JSON {"args":[...], "env":{...}} -> runs tool

Note: This is a lightweight wrapper for POC use. It executes local scripts in mcp/tools/.
"""

import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

ROOT = os.path.dirname(os.path.abspath(__file__))
TOOLS_DIR = os.path.join(ROOT, "tools")


def list_tools():
    tools = []
    for name in os.listdir(TOOLS_DIR):
        if name.endswith(".sh"):
            tools.append(name)
    return sorted(tools)


def run_tool(name, args, env):
    path = os.path.join(TOOLS_DIR, name)
    if not os.path.isfile(path):
        return 404, {"status": "error", "message": f"tool not found: {name}"}
    if not os.access(path, os.X_OK):
        return 500, {"status": "error", "message": f"tool not executable: {name}"}

    cmd = [path] + args
    merged_env = os.environ.copy()
    merged_env.update(env or {})

    try:
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, env=merged_env, text=True)
        return 200, {"status": "ok", "output": out.strip()}
    except subprocess.CalledProcessError as e:
        return 500, {"status": "error", "message": e.output.strip(), "returncode": e.returncode}
    except Exception as e:
        return 500, {"status": "error", "message": f"exception: {type(e).__name__}: {e}"}


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/tools":
            self._send(200, {"tools": list_tools()})
            return
        self._send(404, {"status": "error", "message": "not found"})

    def do_POST(self):
        parsed = urlparse(self.path)
        if not parsed.path.startswith("/tool/"):
            self._send(404, {"status": "error", "message": "not found"})
            return
        name = parsed.path.split("/tool/")[-1]
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8") if length > 0 else "{}"
        try:
            payload = json.loads(raw)
        except Exception:
            self._send(400, {"status": "error", "message": "invalid JSON"})
            return
        args = payload.get("args", [])
        env = payload.get("env", {})
        code, resp = run_tool(name, args, env)
        if code != 200:
            print(f"Tool error: {name} -> {resp}", flush=True)
        self._send(code, resp)


def main():
    host = os.environ.get("MCP_HOST", "127.0.0.1")
    port = int(os.environ.get("MCP_PORT", "8088"))
    httpd = HTTPServer((host, port), Handler)
    print(f"MCP gateway listening on http://{host}:{port}")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
