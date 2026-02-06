# Kafka MCP Ops Console — Current Design (POC)

## 1) Purpose
Provide an end‑to‑end POC for LLM‑assisted Kafka operations with strict tool boundaries, manual security controls, and an operator‑friendly web UI. The system supports troubleshooting, diagnostics, and controlled admin tasks without giving the LLM direct access to Kafka.

## 2) High‑Level Architecture
**User (Web UI)** → **LM Studio API** → **MCP Gateway** → **Kafka CLI Tools** → **Kafka Cluster**

- **Web UI**: Browser chat interface used in demos and day‑to‑day ops testing.
- **LM Studio API**: Local LLM runtime; interprets natural language into tool calls.
- **MCP Gateway**: Executes whitelisted tools; enforces policies (read/write separation, approval, maintenance lock).
- **Kafka Cluster**: 3‑node KRaft cluster with TLS, running in Docker for POC.

## 2.1) Simple Explanation (For Non‑Technical Readers)
Think of the system like a **translator + control gate**:
- You **type a normal question** in the web page (example: “show broker 2 errors”).
- The **LLM (Asif)** translates that into a **safe tool command**.
- The **MCP gateway checks permissions** and only then runs the command.
- You get a **human‑readable answer**, not raw logs.

This means **no one talks to Kafka directly**—everything goes through the controlled gateway.

## 2.2) Example Request Flow (Simple)
**Question:** “List all topics”  
**Action:** LLM chooses `topic_describe` tool  
**Result:** UI shows a clean list of topics  

**Question:** “Create topic demo with 3 partitions and RF 3”  
**Action:** LLM asks for approval → operator clicks **Approve write**  
**Result:** Topic is created and logged in audit file

## 3) Core Design Principles
- **Tool Boundary**: LLM never connects to Kafka directly. MCP executes all operations.
- **Read vs Write**: Read tools are always available; write tools require explicit approval.
- **Security**: ACL/auth/user management is manual (outside LLM).
- **Observability**: Logs, ISR/URP, TLS status, broker health are visible via tools.
- **Air‑gap ready**: Replace LM Studio with enterprise Copilot later; MCP remains the execution boundary.

## 4) Current Components
### 4.1 Kafka Cluster (POC)
- 3 brokers, KRaft mode
- TLS enabled end‑to‑end (self‑signed for POC)
- Per‑broker cert folders
- Client TLS config for Kafka CLI tools

### 4.2 MCP Gateway
- HTTP MCP server (`mcp/server.py`)
- Policy enforcement (`mcp/policy/policy.yaml`)
- Audit log: `mcp/audit.log`

### 4.3 Web UI
- Browser UI with chat, tool panel, timeline, cluster selector
- “Explain error” and “Search web” buttons
- Approval button for write operations

### 4.4 LLM Integration
- LM Studio API Server (`http://127.0.0.1:1234`)
- Web UI invokes LM Studio for NL → tool conversion

## 5) Tooling: Capabilities
### 5.1 Read Tools
- `topic_describe` → `kafka_topic_describe.sh`
- `consumer_group_describe` → `kafka_consumer_group_describe.sh`
- `consumer_lag_snapshot` → `kafka_consumer_lag_snapshot.sh`
- `broker_health` → `kafka_broker_health.sh`
- `broker_status` → `kafka_broker_status.sh`
- `logs_tail` → `kafka_logs_tail.sh`
- `logs_tail_all` → `kafka_logs_tail_all.sh`
- `config_read` → `kafka_config_read.sh` (supports `--all`)
- `metrics_snapshot` → `kafka_metrics_snapshot.sh`
- `tls_status` → `kafka_tls_status.sh`
- `isr_check` → `kafka_isr_check.sh`
- `urp_report` → `kafka_urp_report.sh`
- `disk_health` → `kafka_disk_health.sh`
- `health_dashboard` → `kafka_health_dashboard.sh`

### 5.2 Write Tools (approval required)
- `topic_create` → `kafka_topic_create.sh`
- `topic_delete` → `kafka_topic_delete.sh`
- `topic_alter_partitions` → `kafka_topic_alter_partitions.sh`
- `topic_alter_config` → `kafka_topic_alter_config.sh`
- `reassign_partitions` → `kafka_reassign_partitions.sh`
- `preferred_leader_election` → `kafka_preferred_leader_election.sh`
- `consumer_group_reset_offsets` → `kafka_consumer_group_reset_offsets.sh`
- `tls_rotate` → `kafka_tls_rotate.sh` (placeholder)

## 6) Approval + Audit Flow
- Write tools require `MCP_APPROVED_BY`.
- UI shows “Approve write” button; approval triggers execution.
- All write attempts are logged in `mcp/audit.log`.

## 6.1) In Plain English
- **Read commands** (health, logs, status) work immediately.  
- **Write commands** (create/delete/alter) always require a human click.  
- Every write action is **recorded** for compliance.

## 7) Logging & Troubleshooting
- Log tails can be filtered by severity: `WARN`, `ERROR`, `FATAL`.
- `logs_tail_all` provides cross‑broker error search.
- “Explain error” uses LLM to summarize errors and suggest steps.
- “Search web” opens browser query for troubleshooting.

## 8) Current Limitations
- Docker POC uses container logs; real VM/bare‑metal needs host log paths.
- No AD/RBAC integration yet (planned Phase‑2).
- Multi‑cluster dropdown is UI‑only (backend not wired to per‑cluster configs yet).
- TLS rotation tool is placeholder.

## 8.1) What This Means (Simple)
- This POC is great for **demo and testing**.
- Production will need **real authentication**, **real cluster selection**, and **real log paths**.

## 9) Roadmap (Next Phases)
### Phase‑2 (Enterprise readiness)
- Active Directory / SSO integration
- Role‑based approval enforcement
- Multi‑cluster registry with real connection configs
- Production log path support
- Maintenance window scheduler

### Parallel Track (Go MCP)
- Evaluate Go‑based MCP server
- Mirror tool surface and TLS requirements
- Compare for production readiness

---

**File references**
- `webui/index.html`
- `webui/server.py`
- `mcp/server.py`
- `mcp/policy/policy.yaml`
- `mcp/tool-registry.json`
- `mcp/tools/*`
- `requirements.md`
