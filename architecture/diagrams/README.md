# Architecture Diagrams

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

All diagrams are authored as **Mermaid** (rendered natively by GitHub), collapsed by default inside a `<details>` block (click **📊 Diagram** to expand - this avoids GitHub rendering every diagram at once), each followed by bullet points explaining how to read it; topology and hierarchy diagrams also have an **ASCII** fallback for terminals, wikis and code reviews.

| Diagram | Shows |
|---|---|
| [management-group-hierarchy.md](management-group-hierarchy.md) | ALZ 2026 management group tree, archetypes and subscription placement |
| [hub-and-spoke-topology.md](hub-and-spoke-topology.md) | Customer-managed hubs, spokes, egress and DNS path |
| [virtual-wan-topology.md](virtual-wan-topology.md) | Microsoft-managed vWAN hubs, routing intent and sidecar VNets |
| [oidc-cicd-trust-flow.md](oidc-cicd-trust-flow.md) | OIDC token exchange, identity separation, and the same identities across every delivery platform |
| [delivery-platforms.md](delivery-platforms.md) | End-to-end flows for GitHub Actions, Azure DevOps, HCP Terraform / Terraform Enterprise workspaces and Terraform Stacks |
| [deployment-stages.md](deployment-stages.md) | Day 0 / Day 1 / Day 2 (or Stack) dependencies and state layout |
| [subscription-vending-flow.md](subscription-vending-flow.md) | How a workload team requests and receives a Workload Landing Zone |
| [policy-lifecycle.md](policy-lifecycle.md) | Audit -> Remediate -> Enforce rollout |

More diagrams live next to the text they illustrate:

- [README section 2](../../README.md#2-reference-architecture-at-a-glance) - 14 subsections: end-to-end view, MG hierarchy with policies, Day 1 resources, both topologies with addresses, IPAM, DNS flow, OIDC trust and state, change lifecycle per platform, platform contract, vending, policy lifecycle, monitoring, non-production.
- [docs/03 section 5](../../docs/03-networking-hubspoke-vs-vwan.md#5-sandboxes-canary-and-non-production-environments-in-hub-and-spoke) - sandbox isolation, sandbox lifecycle, "hub in a sandbox" options, canary topology, shared vs separate non-production hub, decision guide.

---

## 🎨 2026 Architectural Infographics (NotebookLM)

The core architecture, governance hierarchy, delivery pipelines, networking topologies, subscription vending engines, and non-production testing strategies of this masterclass are illustrated by high-resolution architectural infographics synthesized with **Gemini NotebookLM**:

| Infographic | Domain / Topic | Resolution | Reference Location |
|---|---|:---:|---|
| [**Enterprise Reference Architecture Framework**](../../docs/assets/img/Enterprise_Cloud_Reference_Architecture_Framework.png) | 2026 Paradigm Shifts (Monolith retirement, Blueprints sunset, AVM, Decoupled ALZ Library, AzAPI-first, Private subnets by default), Hierarchy & Decision Matrix | `2752 x 1536` | [README section 2.1](../../README.md#21-end-to-end-overview) & [docs/01](../../docs/01-architecture-conceptual.md#1-what-a-landing-zone-is-in-2026) |
| [**Architecture & Governance Framework**](../../docs/assets/img/Cloud_Landing_Zone_Architecture_Framework.png) | Management Group Hierarchy, Platform vs Workloads, Policy-as-Code Rollout (Audit -> Remediate -> Enforce), Enforcement Matrix | `2752 x 1536` | [README section 2.2](../../README.md#22-management-group-hierarchy-archetypes-and-subscription-placement) & [docs/01](../../docs/01-architecture-conceptual.md#3-management-group-hierarchy) |
| [**Hub-and-Spoke vs. Virtual WAN Architecture**](../../docs/assets/img/Cloud_Landing_Zone_Networking_Architecture.png) | Customer-Managed Hub-and-Spoke vs vWAN with Routing Intent, Centralized Private DNS, Deterministic `/8` to `/24` IPAM Hierarchy | `2752 x 1536` | [README section 2.4](../../README.md#24-network-topology-a-customer-managed-hub-and-spoke-default) & [docs/03](../../docs/03-networking-hubspoke-vs-vwan.md#1-the-two-supported-topologies) |
| [**Subscription Vending Architecture**](../../docs/assets/img/Cloud_Subscription_Vending_Architecture.png) | Automated Provisioning via single map entry, Resource Group Scaffolding, Spoke Peering, Budget Alerts, Secret-less CI/CD (WIF) | `2752 x 1536` | [README section 2.11](../../README.md#211-subscription-vending-what-one-entry-creates) & [docs/01](../../docs/01-architecture-conceptual.md#4-subscription-model) |
| [**Zero-Secret Delivery: 15-Step OIDC Pipeline**](../../docs/assets/img/15-Step_OIDC_Deployment_Pipeline.png) | 6-Phase / 15-Step Pipeline Lifecycle, Speculative PR Plan, CODEOWNERS Review, Canary Validation, Human Gate, Verbatim Apply, Drift Health | `2752 x 1536` | [README section 2.9](../../README.md#29-delivery-the-lifecycle-of-a-change), [docs/05](../../docs/05-cicd-oidc-security.md#1-principles) & [docs/07](../../docs/07-delivery-platforms.md#1-principle-one-codebase-any-delivery-platform) |
| [**The 3-Tier Non-Production Strategy**](../../docs/assets/img/Three-Tier_Non-Production_Strategy_Diagram.png) | Isolated Sandboxes (`10.15.0.0/16`), Canary Platform Hierarchy with Firewall Basic, Connected Corp Non-Prod (`10.3.0.0/16`) | `2752 x 1536` | [README section 2.14](../../README.md#214-non-production-sandboxes-canary-and-corp-nonprod) & [docs/03](../../docs/03-networking-hubspoke-vs-vwan.md#5-sandboxes-canary-and-non-production-environments-in-hub-and-spoke) |
