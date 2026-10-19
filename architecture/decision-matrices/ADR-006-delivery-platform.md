# ADR-006 - Delivery Platform (CI/CD vs HCP Terraform / TFE vs Stacks)

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

**Status:** Accepted - October 2026 (supersedes the GitHub-only scope of ADR-004)

## Context
The platform team must not operate the landing zone from laptops. The organisation uses GitHub today, some business units standardise on Azure DevOps, and HCP Terraform / Terraform Enterprise is being evaluated for managed state, policy-as-code on plans, continuous drift detection and Terraform Stacks.

## Decision
Make the delivery platform a **deployment-time choice**, not a code fork:

1. All logic lives in provider-less modules (`code/modules/*`).
2. Root modules (`day-1`, `day-2`) carry backend + provider auth that works unchanged on GitHub Actions, Azure DevOps, HCP Terraform and Terraform Enterprise workspaces.
3. A Terraform Stack (`code/hcp-terraform-stacks/alz`) consumes the same modules as components.
4. Day 0 creates **one** pair of identities (plan / apply) and federated credentials per enabled platform.

## Weighted scoring (for a GitHub-hosted, regulated enterprise)

| Criterion | Weight | GitHub Actions | Azure DevOps | HCP TF workspaces | Terraform Enterprise | Terraform Stacks |
|---|---:|---:|---:|---:|---:|---:|
| Secret-less auth & plan/apply split | 20 | 5 | 5 | 5 | 5 | 3 |
| State management effort | 10 | 3 | 3 | 5 | 4 | 5 |
| Ungateable approvals | 15 | 4 | 5 | 4 | 4 | 4 |
| Policy-as-code & drift detection | 15 | 3 | 3 | 5 | 5 | 4 |
| Multi-environment orchestration | 15 | 3 | 4 | 3 | 3 | 5 |
| Data residency / self-hosting | 10 | 3 | 3 | 3 | 5 | 3 |
| Cost & licensing simplicity | 15 | 5 | 4 | 3 | 2 | 3 |
| **Weighted total** | **100** | **3.85** | **4.00** | **4.05** | **4.00** | **3.80** |

The scores are close by design: there is no universally best platform, which is exactly why the code is platform-neutral.

## Consequences
- Contributors change modules once; every platform picks the change up.
- Variable definitions are mirrored between modules, roots and the Stack (keep in sync; CI validates all of them).
- Only one platform may own a given hierarchy at a time.

## Revisit when
Stacks gain plan/apply identity separation, or the organisation consolidates on a single platform (then delete the unused entry points and bootstraps).
