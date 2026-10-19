# Architecture Diagrams

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

All diagrams are authored as **Mermaid** (rendered natively by GitHub), each followed by bullet points explaining how to read it; topology and hierarchy diagrams also have an **ASCII** fallback for terminals, wikis and code reviews.

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
