.PHONY: up prepare

up:
	./kafka-poc-mcp-bootstrap.sh

prepare:
	./kafka-poc-mcp-bootstrap.sh --prepare-only
