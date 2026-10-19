# Subscription Vending Flow (Day 2)

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

How a workload team gets a new Workload Landing Zone, regardless of the delivery platform.

```mermaid
sequenceDiagram
    autonumber
    actor WT as Workload team
    participant Git as Repository (PR)
    participant CO as Platform + FinOps reviewers
    participant DP as Delivery platform
    participant Az as Azure
    WT->>Git: add an entry to workloads.auto.tfvars<br/>(archetype, environment, region, spoke_index, budget)
    Git->>DP: pull request triggers a read-only plan
    DP-->>Git: plan: subscription, spoke CIDR, peering, RBAC, budget
    CO->>Git: review (CODEOWNERS) and merge
    Git->>DP: merge to main
    DP->>CO: request approval of the apply
    CO-->>DP: approve
    DP->>Az: create subscription alias, place it in corp / online / sandbox
    DP->>Az: spoke VNet, NSG, route table, peering or vHub connection
    DP->>Az: RBAC for the team, budget, optional OIDC identity
    DP-->>WT: outputs: subscription ID, CIDRs, DNS servers, deploy identity
    Note over Az: Workload guardrails policies (diagnostics, Defender,<br/>no service endpoints) apply from the first minute
```

**How to read this diagram:**

- **Steps 1-3 - request as code:** the team does not open a ticket; it adds one map entry (the "order form") and the pull request shows exactly what will be created, including the deterministic `/24` spoke range.
- **Step 4 - separation of duties:** CODEOWNERS routes the request to the platform team and FinOps; the workload team cannot approve its own landing zone.
- **Steps 5-7 - gated apply:** the merge triggers the delivery platform (GitHub Actions, Azure DevOps, HCP Terraform / TFE or Stacks), which waits for a human approval before using the privileged identity.
- **Steps 8-10 - fully wired landing zone:** the subscription is placed in the right management group, connected to the hub (peering + firewall route, or a Virtual WAN connection with routing intent), and handed to the team's Entra ID group with a budget and, optionally, an OIDC identity for the team's own pipeline.
- **Step 11 - handover:** the outputs give the team everything needed to deploy workloads; policy guardrails inherited from the management group apply immediately.
