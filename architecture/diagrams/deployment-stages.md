# Deployment Stages & State Layout

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

```mermaid
flowchart LR
    subgraph d0["Day 0 - local, once"]
        a0["State storage + CMK"]
        b0["Entra apps + FICs"]
        c0["RBAC (plan / apply)"]
    end
    subgraph d1["Day 1 - platform (CI)"]
        a1["connectivity RGs"] --> b1["management<br/>(LAW, DCRs, UAMI)"]
        a1 --> c1["hub-and-spoke OR vWAN"]
        b1 & c1 --> d1alz["avm-ptn-alz<br/>MGs, policy, RBAC, placement"]
    end
    subgraph d2["Day 2 - workloads (CI)"]
        rs["remote state read"] --> v["subscription vending"]
        rs --> p["guardrails initiative + remediation"]
        v --> dns["DNS links (exceptions)"]
    end
    d0 --> d1 --> d2
    s0[("tfstate-bootstrap")] -.- d0
    s1[("tfstate-platform")] -.- d1
    s2[("tfstate-workloads")] -.- d2
    s1 -. outputs contract .-> rs
```

| Stage | State container | Key | Runs from | Identity |
|---|---|---|---|---|
| Day 0 | `tfstate-bootstrap` (after migration) | `day-0-bootstrap-oidc.tfstate` | Operator workstation | Human (PIM-elevated) |
| Day 1 | `tfstate-platform` | `day-1-platform-landing-zone.tfstate` | GitHub Actions | plan / apply apps |
| Day 2 | `tfstate-workloads` | `day-2-workload-vending-operations.tfstate` | GitHub Actions | plan / apply apps |
