#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"

export LMSTUDIO_API=${LMSTUDIO_API:-http://127.0.0.1:1234/v1/chat/completions}
export MCP_API=${MCP_API:-http://127.0.0.1:8088}
export WEBUI_PORT=${WEBUI_PORT:-8090}

# Optional approval identity for write tools
if [ -z "$MCP_APPROVED_BY" ]; then
  export MCP_APPROVED_BY=operator
fi

# Start MCP server
python3 "$ROOT/mcp/server.py" > "/tmp/mcp-server.log" 2>&1 &
MCP_PID=$!

# Start Web UI
python3 "$ROOT/webui/server.py" > "/tmp/webui-server.log" 2>&1 &
WEB_PID=$!

trap 'kill $MCP_PID $WEB_PID 2>/dev/null || true' EXIT

echo "MCP server running on $MCP_API"
echo "Web UI running on http://127.0.0.1:${WEBUI_PORT}"

# Wait indefinitely
wait
