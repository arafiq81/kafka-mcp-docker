# Temporary Web UI (LM Studio + MCP)

This provides a simple chat UI in the browser that talks to LM Studio and MCP tools.

## Start MCP server
```sh
python3 mcp/server.py
```

## Start LM Studio API Server
Ensure LM Studio API Server is running at http://127.0.0.1:1234

## Start Web UI
```sh
export LMSTUDIO_API=http://127.0.0.1:1234/v1/chat/completions
export MCP_API=http://127.0.0.1:8088
export MCP_APPROVED_BY=your-name

python3 webui/server.py
```

Open:
- http://127.0.0.1:8090

## Notes
- This is a temporary POC UI.
- Write tools still require approval via MCP_APPROVED_BY.
