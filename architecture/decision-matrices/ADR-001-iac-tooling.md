# ADR-001 - IaC Tooling and Provider Strategy

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

**Status:** Accepted - October 2026

## Context
The CAF enterprise-scale Terraform module was archived on 1 August 2026; ALZ-Bicep classic is being retired (repository archive 16 February 2027). Microsoft's supported path for both languages is Azure Verified Modules plus the ALZ Library.

## Options

| Option | Description |
|---|---|
| A | Terraform: AVM pattern modules + `alz` provider + custom library (this repo) |
| B | Bicep: AVM Bicep accelerator + ALZ Library |
| C | Terraform: hand-written `azurerm`/`azapi` resources, own policy JSON |
| D | Stay on `caf-enterprise-scale` |

## Weighted scoring

| Criterion | Weight | A | B | C | D |
|---|---:|---:|---:|---:|---:|
| Vendor support & longevity | 25 | 5 | 5 | 2 | 1 |
| Policy currency (library updates) | 20 | 5 | 5 | 2 | 1 |
| Multi-cloud / team skills reuse | 15 | 5 | 2 | 5 | 4 |
| State & drift management | 15 | 5 | 3 | 5 | 4 |
| Flexibility / custom resources | 15 | 4 | 4 | 5 | 2 |
| Learning curve | 10 | 3 | 4 | 2 | 4 |
| **Weighted total** | **100** | **4.65** | **4.00** | **3.35** | **2.35** |

## Decision
Option A. Provider rules: AzureRM pinned to `~> 4.x` (v5 unsupported by ALZ modules), AzAPI `~> 2.x` mandatory, `alz` `~> 0.21`, `azuread` only in Day 0, exact module version pins.

## Consequences
- Policy changes become library-ref bumps; code upgrades are independent.
- Inputs to `avm-ptn-alz` must be plan-time known (composed IDs, `*_dependencies` for ordering).
- Teams must learn AzAPI concepts (body, API versions, provider functions).

## Revisit when
AzureRM v5 becomes supported by the ALZ modules; the ALZ modules move fully to AzAPI; the organisation standardises on Bicep.
