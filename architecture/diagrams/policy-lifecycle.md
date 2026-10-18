# Policy Rollout Lifecycle

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

```mermaid
flowchart LR
    A["AUDIT<br/>Deny: DoNotEnforce / Audit<br/>DINE: DoNotEnforce / AuditIfNotExists"] -->|"PR: phase = remediate"| R["REMEDIATE<br/>Deny: still Audit<br/>DINE: DeployIfNotExists<br/>+ remediation tasks"]
    R -->|"PR: phase = enforce"| E["ENFORCE<br/>Deny: Deny<br/>DINE: DeployIfNotExists"]
    E -->|"regression: PR back to audit<br/>(or targeted exemption)"| A
```

```text
 AUDIT ───PR───> REMEDIATE ───PR───> ENFORCE
   │  measure        │ fix existing       │ prevent new
   │  compliance     │ (remediation)      │ (Deny) + keep fixing (DINE)
   └──────── exemptions as code, reviewed by security ────────┘
```
