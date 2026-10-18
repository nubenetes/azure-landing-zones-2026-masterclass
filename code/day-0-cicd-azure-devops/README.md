# Day 0 (optional) - Azure DevOps delivery bootstrap

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

Creates the Azure DevOps side of the zero-secret model so that the YAML pipelines in [`pipelines/azure-devops`](../../pipelines/azure-devops) can run Day 1 and Day 2.

| Resource | Purpose |
|---|---|
| `sc-alz-plan`, `sc-alz-apply` | Workload Identity Federation service connections, scoped to the root parent management group, backed by the Day 0 apps |
| Federated credentials on the Day 0 apps | Trust exactly those two service connections |
| Variable group `alz-iac` | Tenant, subscription, state account, service connection IDs (no secrets) |
| Environment `alz-production` | Approval check (requester cannot approve), exclusive lock, branch control (`main`) |
| Branch control on `sc-alz-apply` | Only `main` can ever use the privileged identity |
| Pipelines `alz-pr-validation`, `alz-apply`, `alz-drift-detection` | YAML from this repository (GitHub service connection or Azure Repos) |
| Pipeline authorisations | `sc-alz-plan` -> all three pipelines; `sc-alz-apply` + environment -> `alz-apply` only |
| Branch policy (Azure Repos only) | Build validation with `alz-pr-validation` on `main` |

## Run

```bash
export AZDO_ORG_SERVICE_URL=https://dev.azure.com/<org>
az login --tenant <tenant-id>           # azuread provider; Entra ID auth for Azure DevOps where supported
cp terraform.tfvars.example terraform.tfvars   # values from Day 0 outputs
terraform init -backend-config=../backend.hcl \
  -backend-config="container_name=tfstate-bootstrap" \
  -backend-config="key=day-0-cicd-azure-devops.tfstate"
terraform apply
```

> [!NOTE]
> Workload identity federation service connections trust **the service connection**, not a branch or environment. That is why the branch-control check on `sc-alz-apply` and the pipeline authorisations are part of the security model, not optional extras.
