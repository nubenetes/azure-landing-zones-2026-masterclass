# Module: `workload-vending`

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../../README.md).

Provider-less subscription vending and workload guardrails. Consumed by the root module [`code/day-2-workload-vending-operations`](../../day-2-workload-vending-operations) and by the `workloads` component of the [Terraform Stack](../../hcp-terraform-stacks/alz).

The Day 1 contract arrives through `var.platform` (never read from state inside the module), so the same code works with Azure Storage remote state, HCP Terraform remote state or a Stacks component reference.

## What a vended Workload Landing Zone contains

| Component | Detail |
|---|---|
| Subscription | New alias (EA/MCA/MPA billing scope) or adoption of an existing subscription; placed in `corp`, `online` or `sandbox` (prefix-aware for canary hierarchies) |
| Network | `/24` spoke from the Day 1 IPAM plan; subnets `snet-app` (/25), `snet-private-endpoints` (/26), `snet-integration` (/27); all private subnets with an NSG |
| Connectivity | Hub peering + UDR `0.0.0.0/0 -> Azure Firewall` (hub-and-spoke) or vHub connection with routing intent (vWAN); sandboxes isolated |
| DNS | Spoke DNS = hub firewall DNS proxy / resolver; optional direct zone links (`dns.tf`) |
| RBAC | Workload Entra group = `Contributor`; network RG protected by a `CanNotDelete` lock |
| Identity | Optional user-assigned identity with a GitHub OIDC federated credential (`environment:<env>`) |
| FinOps | Monthly budget, 80 % actual and 100 % forecast alerts; cost-center tags |

## Governance (`policies.tf`)

Custom initiative **Workload-LZ-Guardrails-2026** assigned at the Workload Landing Zones MG:

| Reference | Definition | Effect by phase (audit / remediate / enforce) |
|---|---|---|
| `diag_keyvault` | Key Vault `allLogs` + `AllMetrics` -> central Log Analytics | AuditIfNotExists / DeployIfNotExists / DeployIfNotExists |
| `defender_storage` | Defender for Storage V2 + on-upload malware scanning cap | AuditIfNotExists / DeployIfNotExists / DeployIfNotExists |
| `deny_service_endpoints` | No service endpoints outside `allowed_service_endpoints` | Audit / Audit / Deny |

> [!NOTE]
> Verify policy aliases and API versions in your tenant (`az provider show --namespace Microsoft.Security --expand "resourceTypes/aliases"`) before promoting beyond `audit`.
