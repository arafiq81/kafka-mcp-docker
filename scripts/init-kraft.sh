#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KAFKA_IMAGE="${KAFKA_IMAGE:-}"

if [ -z "$KAFKA_IMAGE" ]; then
  echo "KAFKA_IMAGE is not set. Example: export KAFKA_IMAGE=apache/kafka:3.x.x"
  exit 1
fi

CLUSTER_ID_FILE="$ROOT_DIR/cluster.id"
if [ -f "$CLUSTER_ID_FILE" ]; then
  CLUSTER_ID=$(cat "$CLUSTER_ID_FILE")
else
  CLUSTER_ID=$(docker run --rm "$KAFKA_IMAGE" /opt/kafka/bin/kafka-storage.sh random-uuid)
  echo "$CLUSTER_ID" > "$CLUSTER_ID_FILE"
fi

echo "Using cluster.id: $CLUSTER_ID"

for i in 1 2 3; do
  CFG="$ROOT_DIR/docker/kafka/broker${i}.properties"
  DATA="$ROOT_DIR/data/broker${i}"
  META="$ROOT_DIR/metadata/broker${i}"

  docker run --rm \
    -v "$CFG":/opt/kafka/config/server.properties:ro \
    -v "$DATA":/var/lib/kafka/data \
    -v "$META":/var/lib/kafka/metadata \
    "$KAFKA_IMAGE" \
    /opt/kafka/bin/kafka-storage.sh format -t "$CLUSTER_ID" -c /opt/kafka/config/server.properties

done

echo "KRaft storage formatted for all brokers."
