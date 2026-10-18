# ADR-004 - CI/CD Platform and Pipeline Identity

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

**Status:** Accepted - October 2026

## Weighted scoring

| Criterion | Weight | GitHub Actions | Azure DevOps |
|---|---:|---:|---:|
| Secret-less Azure auth (OIDC / WIF) | 20 | 5 | 5 |
| Deployment gating | 15 | 4 | 5 |
| Central template governance | 10 | 4 | 5 |
| Collaboration / code review UX | 15 | 5 | 3 |
| Supply-chain security tooling | 15 | 5 | 4 |
| Repository already on GitHub (nubenetes) | 15 | 5 | 2 |
| Enterprise work tracking | 10 | 3 | 5 |
| **Weighted total** | **100** | **4.55** | **4.10** |

## Decision
GitHub Actions. Two Entra app registrations with federated credentials only: **plan** (subjects `pull_request`, `ref:refs/heads/main`; Reader + Blob Data Reader; `-lock=false`) and **apply** (subject `environment:production` only; Owner with ABAC condition + Blob Data Contributor). Actions pinned by SHA, Dependabot enabled.

## Consequences
- Every change to production requires a human approval in the `production` environment.
- The pipeline cannot create privileged role assignments; humans use PIM.

## Revisit when
The organisation mandates Azure Boards/Repos, or requires `extends`-template enforcement beyond GitHub rulesets.
