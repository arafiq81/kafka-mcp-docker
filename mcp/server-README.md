# MCP Gateway (Minimal HTTP Wrapper)

This is a lightweight HTTP wrapper for POC use. It exposes the tools in `mcp/tools/` over HTTP.

## Start
```sh
python3 mcp/server.py
```

## Endpoints
- `GET /tools` -> list available tools
- `POST /tool/<name>` -> run a tool

### Example
```sh
curl -s http://127.0.0.1:8088/tools

curl -s -X POST http://127.0.0.1:8088/tool/kafka_topic_describe.sh \
  -H 'Content-Type: application/json' \
  -d '{"args":["--all"],"env":{}}'
```

## Notes
- Use `env` to pass `MCP_APPROVED_BY`, `MCP_DRY_RUN`, etc.
- This wrapper is intended for local POC only.
