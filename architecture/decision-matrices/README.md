# Decision Matrices (ADR format)

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

Each record follows the same structure: **context -> options -> weighted scoring -> decision -> consequences -> revisit triggers**. Scores are 1 (poor) to 5 (excellent); weights sum to 100 and reflect a regulated enterprise with 1-2 primary regions. Re-weight for your organisation - the method matters more than the numbers.

| ADR | Decision | Status |
|---|---|---|
| [ADR-001](ADR-001-iac-tooling.md) | Terraform + AVM pattern modules + `alz` provider (AzureRM 4.x, AzAPI 2.x) | Accepted |
| [ADR-002](ADR-002-network-topology.md) | Hub-and-spoke by default; Virtual WAN at 3+ regions or 50+ spokes | Accepted |
| [ADR-003](ADR-003-paas-network-access.md) | Private Endpoints by default; Service Endpoints only as approved exceptions | Accepted |
| [ADR-004](ADR-004-cicd-platform.md) | GitHub Actions with OIDC, split identities, environment-gated apply | Accepted |
| [ADR-005](ADR-005-policy-rollout.md) | Phased policy rollout: audit -> remediate -> enforce | Accepted |
| [ADR-006](ADR-006-delivery-platform.md) | Platform-neutral code: GitHub Actions, Azure DevOps, HCP Terraform / TFE workspaces or Terraform Stacks | Accepted |

The narrative comparisons live in [`docs/`](../../docs/); these records capture *why* the repository chose what it chose.
