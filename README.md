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
