# LM Studio MCP Chat (Interactive)

This script provides a chat-style interface that lets you talk to a local LM Studio model and have it call MCP tools.

## Start MCP Gateway
```sh
python3 mcp/server.py
```

## Start LM Studio API Server
Ensure LM Studio API Server is running at `http://127.0.0.1:1234`.

## Run Chat
```sh
export LMSTUDIO_API=http://127.0.0.1:1234/v1/chat/completions
export MCP_API=http://127.0.0.1:8088
export MCP_APPROVED_BY=your-name

python3 lmstudio-mcp-chat.py
```

## Example
```
you> List all topics
assistant> The list of all topics is: ...
```

Type `exit` to quit.
