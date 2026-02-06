# POC Build Plan (Docker + KRaft + TLS)

## A) Repo layout
- docker/
  - compose/ (docker-compose.yaml)
  - kafka/ (broker configs)
  - certs/ (self-signed CA + broker certs)
- scripts/
  - gen-certs.sh (self-signed CA + broker certs)
  - init-kraft.sh (format storage + generate cluster ID)
- logs/
  - broker1/, broker2/, broker3/ (mounted broker log dirs)
- mcp/
  - tools/ (Kafka CLI wrappers)
  - policy/ (maintenance lock + thresholds)

## B) TLS setup (server-only, relaxed hostname verification)
1) Generate CA key + cert
2) Generate server certs for each broker host
3) Create keystores/truststores
4) Configure brokers with SSL listener + truststore
5) Configure CLI/admin clients to use SSL

## C) KRaft cluster setup (3 nodes)
1) Generate cluster.id
2) Format KRaft storage for each broker
3) Bring up brokers with SSL listener
4) Verify controller quorum and broker status

## D) Logging and metrics
1) Mount broker log dirs to logs/brokerX
2) Enable JMX port per broker
3) Verify log files populated and JMX reachable

## E) MCP gateway (no strict approval yet)
1) Define tool wrappers (read/write)
2) Enforce read vs write separation
3) Add maintenance lock flag (manual toggle)
4) Provide health checks before write tools

## F) Smoke tests (manual)
1) Create topic
2) Describe topic
3) Produce/consume with TLS
4) Trigger log warning (e.g., invalid config)
5) Confirm tools read logs/metrics
