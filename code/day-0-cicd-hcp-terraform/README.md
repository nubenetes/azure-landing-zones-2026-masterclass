# Day 0 (optional) - HCP Terraform / Terraform Enterprise delivery bootstrap

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

Creates the HCP Terraform (SaaS) or Terraform Enterprise (self-managed) objects that run this repository - as **workspaces**, as a **Terraform Stack**, or both for evaluation.

| `delivery_model` | Creates |
|---|---|
| `workspaces` | Project `azure-landing-zones`; variable set with dynamic provider credentials (`TFC_AZURE_PROVIDER_AUTH`, `TFC_AZURE_PLAN_CLIENT_ID`, `TFC_AZURE_APPLY_CLIENT_ID`); VCS-driven workspaces `alz-platform` and `alz-workloads` (no auto-apply, speculative plans, health assessments); remote state sharing platform -> workloads; run trigger platform -> workloads; `hcp_platform_workspace` variable on `alz-workloads` |
| `stacks` | Project + Stack `alz` connected to `code/hcp-terraform-stacks/alz` |
| `both` | Both (evaluation only - never manage the same hierarchy twice) |

## Prerequisites

1. Day 0 applied with `hcp_terraform = { hostname, organization, project, workspaces, stack }` matching the values here (they are part of the OIDC subjects).
2. A VCS connection: the HCP Terraform GitHub App installation ID, or an OAuth token ID (TFE / Azure Repos / GitLab).
3. For Terraform Enterprise: version **2.0+** for Stacks, and `hostname` set to your TFE host (also the OIDC issuer).

## Run

```bash
export TFE_TOKEN=<short-lived team token>   # never commit it
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
```

> [!WARNING]
> `validate` for this stage ran against a schema stub derived from the `hashicorp/tfe` 0.82 documentation (the provider binary was unavailable offline). Run `terraform validate` with the real provider before use.
