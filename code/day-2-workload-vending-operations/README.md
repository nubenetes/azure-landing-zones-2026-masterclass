# Day 2 - Workload Vending & Operations

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

## What a vended Workload Landing Zone contains

| Component | Detail |
|---|---|
| Subscription | New alias (EA/MCA/MPA billing scope) or adoption of an existing subscription; placed in `corp`, `online` or `sandbox` |
| Network | `/24` spoke from the Day 1 IPAM plan; subnets `snet-app` (/25), `snet-private-endpoints` (/26), `snet-integration` (/27); all **private subnets** with an NSG |
| Connectivity | Hub peering + UDR `0.0.0.0/0 -> Azure Firewall` (hub-and-spoke) or vHub connection with routing intent (vWAN); sandboxes stay isolated |
| DNS | Spoke DNS = hub firewall DNS proxy / resolver; optional direct zone links (`dns.tf`) |
| RBAC | Workload Entra group = `Contributor`; network RG protected by a `CanNotDelete` lock |
| Identity | Optional user-assigned identity with a GitHub OIDC federated credential (`environment:<env>`) for the workload's own pipeline |
| FinOps | Monthly budget with 80 % actual and 100 % forecast alerts; cost-center tags |

## Governance (`policies.tf`)

Custom initiative **Workload-LZ-Guardrails-2026** assigned at `landingzones`:

| Reference | Definition | Effect by phase (audit / remediate / enforce) |
|---|---|---|
| `diag_keyvault` | Key Vault `allLogs` + `AllMetrics` -> central Log Analytics | AuditIfNotExists / DeployIfNotExists / DeployIfNotExists |
| `defender_storage` | Defender for Storage V2 + on-upload malware scanning cap | AuditIfNotExists / DeployIfNotExists / DeployIfNotExists |
| `deny_service_endpoints` | No service endpoints outside `allowed_service_endpoints` | Audit / Audit / Deny |

Remediation tasks are created in the `remediate` and `enforce` phases.

> [!NOTE]
> Policy aliases and API versions used in `policies/*.json` should be verified in your tenant (`az provider show --namespace Microsoft.Security --expand "resourceTypes/aliases"`) before promotion beyond `audit`.

## Requesting a landing zone (workload teams)

1. Add an entry to `workload_landing_zones` in `terraform.tfvars` (copy an example).
2. Pick a free `spoke_index` for your region/archetype/environment (validation rejects collisions).
3. Open a PR - the plan comment shows the subscription, CIDRs, peering, RBAC and budget.
4. Platform + FinOps approve; the merge triggers the gated apply.
