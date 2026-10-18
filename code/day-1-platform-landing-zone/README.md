# Day 1 - Platform Landing Zone (Azure Verified Modules)

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

## Composition

| Module | Version | Deploys |
|---|---|---|
| `Azure/avm-res-resources-resourcegroup/azurerm` | 0.4.0 | Connectivity resource groups (hub per region, DNS, DDoS) |
| `Azure/avm-ptn-alz-management/azurerm` | 0.9.0 | Log Analytics (Entra-only), AMA user-assigned identity, DCRs (VM Insights, Change Tracking, Defender for SQL), optional Sentinel |
| `Azure/avm-ptn-alz-connectivity-hub-and-spoke-vnet/azurerm` | 0.17.7 | Hub VNets, Azure Firewall + policy (DNS proxy), gateways, Bastion, Private DNS Resolver, DNS Security Policy, Private Link DNS zones, DDoS plan |
| `Azure/avm-ptn-alz-connectivity-virtual-wan/azurerm` | 0.18.0 | vWAN, secured virtual hubs, sidecar VNets, resolver, Bastion, zones |
| `Azure/avm-ptn-alz/azurerm` | 0.22.0 | Management groups, policy definitions / initiatives / assignments, role assignments, subscription placement |

## Files

| File | Content |
|---|---|
| `terraform.tf` | Version constraints, partial `azurerm` backend |
| `providers.tf` | `alz` (custom library), `azapi` and `azurerm` (default = management, alias = connectivity) |
| `variables.tf` | Inputs with validation |
| `locals.tf` | IPAM, names, plan-time-known IDs, policy defaults, **policy rollout phase**, policy overrides |
| `main.tf` | Module composition and ordering |
| `outputs.tf` | Contract consumed by Day 2 |
| `lib/` | Custom ALZ library (architecture, archetype overrides, extra assignments) |

## Run

```bash
cp terraform.tfvars.example terraform.tfvars        # commit it - identifiers only
terraform init -backend-config=../backend.hcl \
  -backend-config="container_name=tfstate-platform" \
  -backend-config="key=day-1-platform-landing-zone.tfstate"
terraform plan -out=tfplan
```

In normal operation this stack is applied **only** by `terraform-apply.yml`.

## Customising governance

| I want to... | Do this |
|---|---|
| Adopt Microsoft's latest policies | Bump `ref` in `lib/alz_library_metadata.json` |
| Remove an assignment from an archetype | Add it to `policy_assignments_to_remove` in the archetype override YAML |
| Change a parameter / enforcement | Add an entry to `static_modification_list` in `locals.tf` |
| Roll out gradually | `policy_enforcement_phase`: `audit` -> `remediate` -> `enforce` |
| Restrict regions | `allowed_locations = ["westeurope", "northeurope"]` |
| Rename / restructure MGs | Edit `lib/architecture_definitions/*.yaml` (plan carefully - IDs are identities) |

> [!IMPORTANT]
> Do not feed module outputs into `avm-ptn-alz` inputs. The `alz` provider needs plan-time-known values; ordering is achieved with `policy_assignments_dependencies` and `policy_role_assignments_dependencies`.
