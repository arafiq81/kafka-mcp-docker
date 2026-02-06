# MCP Tool Usage Examples (Human Language)

Each example shows a natural-language request and the tool call it maps to.

## Read examples

- "List all topics"
  - Tool: `kafka_topic_describe.sh`
  - Args: `--all`

- "Describe topic test-rf3"
  - Tool: `kafka_topic_describe.sh`
  - Args: `test-rf3`

- "Show consumer group my-group"
  - Tool: `kafka_consumer_group_describe.sh`
  - Args: `my-group`

- "Check broker 1 health"
  - Tool: `kafka_broker_health.sh`
  - Args: `1`

- "Tail broker 1 logs, last 50 lines"
  - Tool: `kafka_logs_tail.sh`
  - Args: `1 50`

- "Check TLS expiry for all brokers"
  - Tool: `kafka_tls_status.sh`
  - Args: `--all`

- "Check ISR health"
  - Tool: `kafka_isr_check.sh`
  - Args: (none)

- "Show health dashboard"
  - Tool: `kafka_health_dashboard.sh`
  - Args: (none)

- "Read topic config for test-rf2"
  - Tool: `kafka_config_read.sh`
  - Args: `topic test-rf2`

## Write examples (approval required)

- "Create topic demo with 3 partitions and RF=3"
  - Tool: `kafka_topic_create.sh`
  - Args: `demo 3 3`

- "Delete topic demo"
  - Tool: `kafka_topic_delete.sh`
  - Args: `demo`

- "Increase partitions of demo to 6"
  - Tool: `kafka_topic_alter_partitions.sh`
  - Args: `demo 6`

- "Set retention.ms to 600000 on demo"
  - Tool: `kafka_topic_alter_config.sh`
  - Args: `demo retention.ms=600000`

- "Run preferred leader election"
  - Tool: `kafka_preferred_leader_election.sh`
  - Args: (none)

- "Reset group g1 offsets for demo to earliest"
  - Tool: `kafka_consumer_group_reset_offsets.sh`
  - Args: `g1 demo to-earliest`
