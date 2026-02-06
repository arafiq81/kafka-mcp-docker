# Demo Checklist (Kafka MCP POC)

## Pre-demo
- [ ] Run `./kafka-poc-mcp-bootstrap.sh`
- [ ] Web UI opens at `http://127.0.0.1:8090`
- [ ] MCP server running at `http://127.0.0.1:8088`
- [ ] Kafka brokers up (`docker ps` shows kafka1/2/3)

## Live demo flow
1) **Inventory**: `list topic names`
2) **Inspect**: `describe topic poc-test`
3) **Health**: `check ISR health`
4) **Logs**: `tail broker 1 logs last 20`
5) **Create**: `create topic demo-ui with 3 partitions and rf 3`
6) **Delete**: `delete topic demo-ui`

## Optional scenarios
- **Under-replication**: stop one broker, run `check ISR health`
- **Logs filter**: `search errors in logs of broker 2`
- **TLS status**: `show tls status`

## If something fails
- If output looks stale: restart web UI and retry
- If approvals block writes: click **Approve**
- If command sounds like CLI: rephrase in natural language
