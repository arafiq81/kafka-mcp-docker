# Kafka MCP POC (Docker)

## User manual (quick guide)

### Required software (pre-install)
- Docker Desktop
- Java 17+ (for keytool)
- Python 3.10+
- Git

### Step-by-step deployment (from Git)
1) Clone the repo:
   ```sh
   git clone https://github.com/arafiq81/kafka-mcp-docker
   cd kafka-mcp-docker
   ```
2) Run the bootstrap script:
   ```sh
   ./kafka-poc-mcp-bootstrap.sh
   ```
3) Open the Web UI:
   ```
   http://127.0.0.1:8090
   ```
4) Confirm Kafka is up:
   ```sh
   docker ps
   ```

### Possible scenarios (POC)
- **Topic operations**: create, delete, describe, alter partitions.
- **Health checks**: ISR health, broker health, disk health.
- **Log analysis**: tail logs by broker, filter errors/warnings.
- **TLS checks**: validate certificate expiry.
- **Approval flow**: write operations require approval.

### Architecture overview (high level)
```
User -> Web UI -> LM Studio (LLM) -> MCP Gateway -> Kafka Tools -> Kafka Cluster
```

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
