# ADR-003 - PaaS Network Access

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

**Status:** Accepted - October 2026

## Weighted scoring

| Criterion | Weight | Private Endpoints | Service Endpoints (+ policies) | Public + firewall rules |
|---|---:|---:|---:|---:|
| Removes public exposure | 25 | 5 | 2 | 1 |
| Exfiltration / multi-tenant isolation | 20 | 5 | 3 | 1 |
| Inspection & logging | 15 | 5 | 2 | 3 |
| Hybrid / cross-region reachability | 10 | 5 | 1 | 4 |
| Cost | 15 | 2 | 5 | 5 |
| Operational simplicity | 15 | 2 | 4 | 4 |
| **Weighted total** | **100** | **4.10** | **2.85** | **2.65** |

## Decision
Private Endpoints by default (corp: `Deny-Public-Endpoints` + `Deploy-Private-DNS-Zones`). Service Endpoints are denied in all workload landing zones unless listed in `allowed_service_endpoints` (`Deny-Subnet-Service-Endpoints`), and then only together with Service Endpoint Policies where supported.

## Consequences
- Central DNS is a tier-0 dependency (resolver + zones are zone-redundant and monitored).
- Each spoke reserves a `/26` for Private Endpoints.
- Per-endpoint and per-GB costs appear in workload budgets.

## Revisit when
A service lacks Private Link support for a critical workload, or Network Security Perimeter coverage makes perimeter-based access preferable for specific PaaS services.
