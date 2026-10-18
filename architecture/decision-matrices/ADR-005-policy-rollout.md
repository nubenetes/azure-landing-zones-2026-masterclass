# ADR-005 - Policy Rollout Strategy

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

**Status:** Accepted - October 2026

## Options

| Option | Description |
|---|---|
| A | Phased: audit -> remediate -> enforce, promoted by PR (this repo) |
| B | Big-bang: deploy ALZ with full enforcement on day one |
| C | Audit-only forever, manual remediation |

## Weighted scoring

| Criterion | Weight | A | B | C |
|---|---:|---:|---:|---:|
| Brownfield safety (no outage) | 30 | 5 | 1 | 5 |
| Time to secure state | 20 | 3 | 5 | 1 |
| Evidence for auditors | 20 | 5 | 3 | 2 |
| Developer trust / friction | 15 | 5 | 2 | 4 |
| Operational effort | 15 | 3 | 4 | 2 |
| **Weighted total** | **100** | **4.30** | **2.80** | **3.00** |

## Decision
Option A, implemented as `policy_enforcement_phase` in Day 1 (enforcement mode on curated ALZ assignments) and Day 2 (effects + remediation tasks of the custom initiative). Greenfield tenants may start at `enforce` (variable default in Day 1).

## Consequences
- A tenant can sit in a mixed state; the phase is visible in code, PRs and assignment descriptions.
- Exemptions are code with expiry dates.

## Revisit when
Compliance > 95 % for two consecutive months (remove the phase toggle for stable controls) or a new library version introduces many new Deny assignments (re-enter audit for those).
