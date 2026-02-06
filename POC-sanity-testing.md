# POC Sanity Testing

## Assumptions
- Kafka is running (3 brokers, TLS enabled).
- Use TLS client config: `/opt/kafka/config/client.properties`
- Run commands inside `kafka1` container unless noted.

## Test Scenario
Create 3 topics with varying replication and produce 100 messages each.

### 1) Create topics
```sh
# Test 1 - replication 3
docker exec kafka1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka1:9093 \
  --command-config /opt/kafka/config/client.properties \
  --create --topic test-rf3 --partitions 3 --replication-factor 3

# Test 2 - replication 2
docker exec kafka1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka1:9093 \
  --command-config /opt/kafka/config/client.properties \
  --create --topic test-rf2 --partitions 3 --replication-factor 2

# Test 3 - replication 1
docker exec kafka1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka1:9093 \
  --command-config /opt/kafka/config/client.properties \
  --create --topic test-rf1 --partitions 3 --replication-factor 1
```

### 2) Produce 100 messages per topic
```sh
# test-rf3
seq 1 100 | sed 's/^/msg-/' | \
  docker exec -i kafka1 /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server kafka1:9093 \
    --producer.config /opt/kafka/config/client.properties \
    --topic test-rf3

# test-rf2
seq 1 100 | sed 's/^/msg-/' | \
  docker exec -i kafka1 /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server kafka1:9093 \
    --producer.config /opt/kafka/config/client.properties \
    --topic test-rf2

# test-rf1
seq 1 100 | sed 's/^/msg-/' | \
  docker exec -i kafka1 /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server kafka1:9093 \
    --producer.config /opt/kafka/config/client.properties \
    --topic test-rf1
```

### 3) Verify message counts (consume all)
```sh
# test-rf3
docker exec kafka1 /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server kafka1:9093 \
  --consumer.config /opt/kafka/config/client.properties \
  --topic test-rf3 --from-beginning --timeout-ms 5000

# test-rf2
docker exec kafka1 /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server kafka1:9093 \
  --consumer.config /opt/kafka/config/client.properties \
  --topic test-rf2 --from-beginning --timeout-ms 5000

# test-rf1
docker exec kafka1 /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server kafka1:9093 \
  --consumer.config /opt/kafka/config/client.properties \
  --topic test-rf1 --from-beginning --timeout-ms 5000
```

## Requested Commands

### Read all topics
```sh
docker exec kafka1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka1:9093 \
  --command-config /opt/kafka/config/client.properties --list
```

### Define topics (create)
```sh
# RF=3
docker exec kafka1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka1:9093 \
  --command-config /opt/kafka/config/client.properties \
  --create --topic <topic> --partitions <n> --replication-factor 3

# RF=2
docker exec kafka1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka1:9093 \
  --command-config /opt/kafka/config/client.properties \
  --create --topic <topic> --partitions <n> --replication-factor 2

# RF=1
docker exec kafka1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka1:9093 \
  --command-config /opt/kafka/config/client.properties \
  --create --topic <topic> --partitions <n> --replication-factor 1
```

### Under-replicated partitions (detect + remediate)
```sh
# Detect under-replicated partitions
docker exec kafka1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka1:9093 \
  --command-config /opt/kafka/config/client.properties \
  --describe --under-replicated-partitions

# Preferred leader election (helps rebalance leaders; not a full URP fix)
docker exec kafka1 /opt/kafka/bin/kafka-preferred-replica-election.sh \
  --bootstrap-server kafka1:9093 \
  --command-config /opt/kafka/config/client.properties

# If URPs persist, run a reassignment plan (manual plan required)
# 1) Generate plan JSON, then execute:
#docker exec kafka1 /opt/kafka/bin/kafka-reassign-partitions.sh \
#  --bootstrap-server kafka1:9093 \
#  --command-config /opt/kafka/config/client.properties \
#  --reassignment-json-file /opt/kafka/config/reassign.json --execute
```

