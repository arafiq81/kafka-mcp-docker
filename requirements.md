# Kafka POC Requirements

## Purpose
Build a local, Docker-based Kafka POC to validate LLM-assisted operations, troubleshooting, and health guidance with strict operational controls. The design must be airgap-ready and support later integration with an enterprise-approved LLM.

## Scope
- 3-node Kafka cluster in KRaft mode (no ZooKeeper).
- TLS enabled for Kafka listeners using self-signed certificates.
- LLM-assisted operations via an MCP server (gateway).
- Security operations (ACLs, auth, user management) remain manual.

## Out of Scope
- Production deployment to a real environment.
- Automated ACL/auth/user management.
- External internet dependencies (airgap support required).

## Functional Requirements
- Provision a 3-broker Kafka cluster locally using Docker.
- Use KRaft mode with a 3-node controller quorum.
- Configure Kafka listeners with **server-only TLS** using self-signed certs.
- Provide LLM-assisted ops via a tool gateway (MCP server).
- LLM may automate TLS operations (e.g., rotation) with approvals.
- Expose read-only health/log/metric tools to LLM at all times.
- Gate write operations through approvals and maintenance windows.

## Operational Requirements
- A maintenance lock must block all write operations by default.
- Read-only operations must remain available during maintenance.
- All write operations require:
  - health checks
  - dry-run or plan preview when applicable
  - explicit human approval

## Tooling Requirements (MCP/Gateway)
- Provide explicit tool separation: read vs write.
- Enforce policy for maintenance windows and approvals.
- Support policy configuration for thresholds and roles.

## LLM Integration Requirements
- Local LLM for POC: LM Studio.
- Future airgapped enterprise LLM: Copilot (or equivalent).
- LLM should **not** connect to Kafka directly; it uses MCP/gateway.

## Observability Requirements
- Access to broker logs with filtering by severity/time.
- Access to broker health and cluster state (URPs, ISR changes, offline partitions).
- Access to basic performance metrics (latency, throughput, disk usage).

## Security Requirements
- TLS required for Kafka listeners (self-signed OK).
- ACL/auth/user management handled manually.
- LLM write operations must never bypass human approval.

## Deliverables
- Architecture diagram and data-flow description.
- MCP tool list and maintenance policy definition.
- Docker/KRaft/TLS implementation steps (after architecture approval).

## Acceptance Criteria
- Kafka 3-node cluster runs locally in Docker with TLS enabled.
- MCP/gateway enforces read vs write separation and maintenance lock.
- LLM can perform read-only diagnostics and propose write actions.
- Manual approval is required for all write actions.

## POC Decisions (Locked)
- Kafka version: latest stable minus 1 at implementation time.
- Container image: choose simplest option at implementation time (official image or binaries).
- TLS: end-to-end TLS for all clients/admin tools; relaxed hostname verification for POC.
- Listener layout: single SSL listener for simplicity.
- Metrics: JMX only (no Prometheus).
- Logs: broker log files on mounted volumes (node-like logging).
- MCP: use MCP server for tool gateway.
- Approval workflow: strict enforcement deferred to Phase 2.

