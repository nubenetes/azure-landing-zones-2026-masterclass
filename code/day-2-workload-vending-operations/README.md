# Day 2 - Workload Vending & Operations (root module)

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

Thin entry point: reads the Day 1 platform contract and calls [`../modules/workload-vending`](../modules/workload-vending).

| Delivery platform | Where the Day 1 contract comes from |
|---|---|
| GitHub Actions / Azure DevOps / local | `platform_state` -> Azure Storage remote state |
| HCP Terraform / TFE workspaces | `hcp_platform_workspace` (set as a workspace variable by `code/day-0-cicd-hcp-terraform`) -> `remote` backend state sharing |
| Terraform Stacks | Not used - the Stack passes `component.platform` outputs directly |

## Requesting a landing zone (workload teams)

1. Add an entry to `workload_landing_zones` in **`workloads.auto.tfvars`** (start from `terraform.tfvars.example`).
2. Pick a free `spoke_index` for your region/archetype/environment (validation rejects collisions).
3. Open a PR - the platform posts the plan (PR comment, pipeline summary or HCP speculative plan).
4. Platform + FinOps approve (CODEOWNERS); the merge triggers the gated apply.
