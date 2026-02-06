#!/bin/bash
# Shared MCP tool settings

export KAFKA_CONTAINER=${KAFKA_CONTAINER:-kafka1}
export KAFKA_BOOTSTRAP=${KAFKA_BOOTSTRAP:-kafka1:9093}
export KAFKA_CLIENT_CFG=${KAFKA_CLIENT_CFG:-/opt/kafka/config/client.properties}
