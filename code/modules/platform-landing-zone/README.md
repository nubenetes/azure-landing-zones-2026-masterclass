# Module: `platform-landing-zone`

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../../README.md).

Provider-less composition of the ALZ platform landing zone with Azure Verified Modules. Consumed by the root module [`code/day-1-platform-landing-zone`](../../day-1-platform-landing-zone) (GitHub Actions, Azure DevOps, HCP Terraform / TFE workspaces) and by the `platform` component of the [Terraform Stack](../../hcp-terraform-stacks/alz).

| Module | Version | Deploys |
|---|---|---|
| `Azure/avm-res-resources-resourcegroup/azurerm` | 0.4.0 | Connectivity resource groups (AzAPI-based) |
| `Azure/avm-ptn-alz-management/azurerm` | 0.9.0 | Log Analytics (Entra-only), AMA identity, DCRs, optional Sentinel |
| `Azure/avm-ptn-alz-connectivity-hub-and-spoke-vnet/azurerm` | 0.17.7 | Hub VNets, Azure Firewall (DNS proxy), gateways, Bastion, Private DNS Resolver, DNS Security Policy, Private Link zones, DDoS |
| `Azure/avm-ptn-alz-connectivity-virtual-wan/azurerm` | 0.18.0 | vWAN, secured hubs, sidecar VNets |
| `Azure/avm-ptn-alz/azurerm` | 0.22.0 | Management groups, policy, RBAC, subscription placement |

## Providers the caller must pass

| Local name | Context |
|---|---|
| `alz` | `library_references = [{ custom_url = <path or git URL to ./lib> }]` |
| `azapi`, `azurerm` | Management subscription |
| `azapi.connectivity`, `azurerm.connectivity` | Connectivity subscription |
| `modtm`, `random`, `time` | Default instances (explicitly required by Terraform Stacks) |

## Customising governance

| I want to... | Do this |
|---|---|
| Adopt Microsoft's latest policies | Bump `ref` in `lib/alz_library_metadata.json` |
| Remove an assignment from an archetype | `policy_assignments_to_remove` in the archetype override YAML |
| Change a parameter / enforcement | Add an entry to `static_modification_list` in `locals.tf` |
| Roll out gradually | `policy_enforcement_phase`: `audit` -> `remediate` -> `enforce` |
| Restrict regions | `allowed_locations = ["westeurope", "northeurope"]` |
| Test changes in a canary hierarchy | `architecture_name = "alz_2026_masterclass_canary"` + `management_group_id_prefix = "canary-"` |
| Rename / restructure MGs | Edit `lib/architecture_definitions/*.yaml` (keep production and canary in sync) |

> [!IMPORTANT]
> Never feed values that are *known after apply* into `avm-ptn-alz`. IDs are composed in `locals.tf`; ordering uses `policy_assignments_dependencies` / `policy_role_assignments_dependencies`.

The outputs in `outputs.tf` are the **platform contract** consumed by the `workload-vending` module.
