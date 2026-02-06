#!/bin/sh
set -e

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PREPARE_ONLY=0

usage() {
  echo "Usage: $0 [--prepare-only]"
}

if [ "$#" -gt 0 ]; then
  case "$1" in
    --prepare-only) PREPARE_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
fi

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing dependency: $1"
    exit 1
  fi
}

need_cmd docker
need_cmd python3
need_cmd java

# Prefer docker compose if available, else docker-compose
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
else
  need_cmd docker-compose
  DC="docker-compose"
fi

cd "$ROOT"

# Generate certs
if [ -x "$ROOT/scripts/gen-certs.sh" ]; then
  echo "Generating TLS certs..."
  "$ROOT/scripts/gen-certs.sh"
else
  echo "Missing scripts/gen-certs.sh"
  exit 1
fi

# Bring up Kafka cluster
if [ -f "$ROOT/docker/compose/docker-compose.yml" ]; then
  echo "Starting Kafka docker compose..."
  KAFKA_IMAGE=${KAFKA_IMAGE:-apache/kafka:3.7.0}
  export KAFKA_IMAGE
  (cd "$ROOT/docker/compose" && $DC up -d)
else
  echo "Missing docker/compose/docker-compose.yml"
  exit 1
fi

if [ "$PREPARE_ONLY" -eq 1 ]; then
  echo "Prepare-only mode complete."
  exit 0
fi

# Start MCP + Web UI (uses run-chat.sh if present)
if [ -x "$ROOT/run-chat.sh" ]; then
  echo "Starting MCP + Web UI..."
  "$ROOT/run-chat.sh"
else
  echo "Missing run-chat.sh; please start MCP and Web UI manually."
  exit 1
fi

