# Day 1 - Platform Landing Zone (root module)

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

Thin entry point: **backend + provider authentication** only. All logic is in [`../modules/platform-landing-zone`](../modules/platform-landing-zone).

| File | Content |
|---|---|
| `terraform.tf` | Version constraints, partial `azurerm` backend (HCP Terraform / TFE override it during remote runs) |
| `providers.tf` | `alz`, `azapi`, `azurerm` (management + connectivity). Auth via `ARM_*` env (GitHub Actions, Azure DevOps) or `var.tfc_azure_dynamic_credentials` (HCP Terraform / TFE) |
| `variables.tf` | Mirror of the module's variables + `tfc_azure_dynamic_credentials` |
| `main.tf` | `module "platform"` |
| `outputs.tf` | Re-exported platform contract (read by Day 2) |
| `terraform.tfvars.example` | Example values - copy to **`platform.auto.tfvars`** and commit (identifiers only) |

> [!IMPORTANT]
> Use `*.auto.tfvars` for committed values: every platform loads it, while Terraform Enterprise ignores `terraform.tfvars` and HCP Terraform workspace variables take precedence over `.auto.tfvars`.

## How it runs

| Platform | Trigger | Defined in |
|---|---|---|
| GitHub Actions | PR -> plan; push to `main` -> plan + approval + apply | `.github/workflows/terraform-*.yml` |
| Azure DevOps | PR -> plan; `main` -> plan + environment approval + apply | `pipelines/azure-devops/*.yml` |
| HCP Terraform / TFE | VCS-driven workspace `alz-platform` (speculative plans on PRs, confirm apply) | `code/day-0-cicd-hcp-terraform` |
| Local CLI | Break-glass only | - |

Local break-glass run:

```bash
cp terraform.tfvars.example platform.auto.tfvars
terraform init -backend-config=../backend.hcl \
  -backend-config="container_name=tfstate-platform" \
  -backend-config="key=day-1-platform-landing-zone.tfstate"
terraform plan -out=tfplan
```
