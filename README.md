# Kafka MCP POC (Docker)

## Quick start (single command)
```sh
./kafka-poc-mcp-bootstrap.sh
```

## Prepare-only (no services started)
```sh
./kafka-poc-mcp-bootstrap.sh --prepare-only
```

## Makefile shortcut
```sh
make up
```

## What it does
- Validates dependencies (docker, python3, java)
- Generates TLS certs
- Starts Kafka via docker compose
- Starts MCP + Web UI

## Notes
- Default Kafka image: `apache/kafka:3.7.0`
- Override with: `KAFKA_IMAGE=apache/kafka:3.7.0 ./kafka-poc-mcp-bootstrap.sh`

## Demo script (7 steps)
1) Open Web UI: `http://127.0.0.1:8090`
2) Prompt: `list topic names`
3) Prompt: `describe topic poc-test`
4) Prompt: `check ISR health`
5) Prompt: `tail broker 1 logs last 20`
6) Prompt: `create topic demo-ui with 3 partitions and rf 3`
7) Prompt: `delete topic demo-ui`

## Demo checklist
See `DEMO-CHECKLIST.md` for a live walkthrough and troubleshooting tips.
