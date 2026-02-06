# MCP Tool Extension Guide

## Core Principles
- Write tools must include: health checks, dry-run, explicit approval.
- Read tools must be side-effect free.

## Checklist for Adding Tools

### 1) Define Scope
- Decide if the tool is `read` or `write`.
- Clarify which Kafka domain it affects (topics, groups, replication, configs, logs, metrics).

### 2) Name + Interface
- Use consistent naming: `kafka_<action>_<object>.sh`
- Document required arguments and environment variables.

### 3) Policy Wiring
- Add the tool to `mcp/policy/policy.yaml` under `read_tools` or `write_tools`.
- If write: define maintenance window allow/deny behavior.

### 4) Safety Gates (Write Tools)
- **Health checks**: verify controller stability, broker availability, URP thresholds.
- **Dry-run**: show impact or plan before execution.
- **Approval**: explicit human approval before any write.

### 5) Read Tool Constraints
- Ensure no side effects.
- Only query or observe state.

### 6) Implementation Notes
- Prefer `docker exec` with TLS client config.
- Return JSON: `{status, output/message, metadata}`.

### 7) Testing
- Add a test scenario to `POC-sanity-testing.md`.
- Validate tool output is deterministic and safe.

## Future Enhancements
- Add RBAC roles for tool execution.
- Integrate maintenance window scheduler.
- Add audit logging for every tool call.

