# Kafka POC Architecture (Mermaid)

```mermaid
flowchart LR
  subgraph UserOps[Operator]
    U[Human Operator]
  end

  subgraph LLM[LLM Layer]
    LM[LM Studio (Local LLM)]
  end

  subgraph MCP[MCP Gateway]
    G[MCP Server / Tool Gateway]
    P[Policy Engine
(Maintenance Lock
+ Approval Gate)]
  end

  subgraph Kafka[Kafka Cluster (KRaft, TLS)]
    B1[Broker 1]
    B2[Broker 2]
    B3[Broker 3]
  end

  subgraph Obs[Observability]
    L1[Broker Logs]
    M1[Metrics/JMX]
  end

  U -->|Requests + Approvals| LM
  LM -->|Tool Calls| G
  G --> P

  G -->|Read/Write CLI Ops| Kafka
  Kafka -->|Logs| L1
  Kafka -->|Metrics| M1

  L1 --> G
  M1 --> G

  P -.->|Allow/Block| G

  classDef muted fill:#f5f5f5,stroke:#999,color:#333;
  class Obs,UserOps muted;
```

## Data Flow (Summary)
1) Operator asks LLM for an action or diagnosis.
2) LLM issues tool calls to MCP Gateway.
3) MCP enforces policy (maintenance lock, approvals, health checks).
4) MCP runs Kafka CLI ops or fetches logs/metrics.
5) Results return to LLM; operator approves or rejects write actions.

## Notes
- TLS is server-only for Kafka listeners.
- ACL/auth/user management remains manual (out of scope for MCP tools).
- Write actions require approval; read actions are always allowed.
