# LM Studio ↔ MCP Bridge

This is a minimal bridge script that lets LM Studio call MCP tools.

## Prereqs
- LM Studio API Server running at `http://127.0.0.1:1234`
- MCP Gateway running at `http://127.0.0.1:8088`

## Start MCP Gateway
```sh
python3 mcp/server.py
```

## Run the Bridge
```sh
export LMSTUDIO_API=http://127.0.0.1:1234/v1/chat/completions
export MCP_API=http://127.0.0.1:8088
export MCP_APPROVED_BY=your-name

python3 lmstudio-mcp-bridge.py "List all topics"
```

## Notes
- The model is instructed to return JSON only.
- Tools are invoked via MCP and results are sent back to the model.
- For write tools, approval is required via `MCP_APPROVED_BY`.
