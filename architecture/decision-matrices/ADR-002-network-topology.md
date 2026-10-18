# ADR-002 - Network Topology

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

**Status:** Accepted - October 2026

## Context
Initial footprint: West Europe (primary) and North Europe (secondary), ~20 spokes in year one, ExpressRoute to two data centres, no SD-WAN estate, requirement for TLS inspection and custom egress rules.

## Weighted scoring

| Criterion | Weight | Hub-and-spoke | Virtual WAN |
|---|---:|---:|---:|
| Fit for current region count (2) | 15 | 5 | 3 |
| Fit for 24-month spoke forecast (< 50) | 15 | 5 | 4 |
| Routing control / custom NVA chains | 15 | 5 | 3 |
| Base cost | 15 | 5 | 3 |
| Operational toil at forecast scale | 15 | 3 | 5 |
| Branch / SD-WAN integration | 10 | 2 | 5 |
| Global transit simplicity | 10 | 3 | 5 |
| Reversibility | 5 | 5 | 3 |
| **Weighted total** | **100** | **4.20** | **3.85** |

## Decision
Hub-and-spoke (`connectivity_type = "hub_and_spoke_vnet"`), one hub per region with Azure Firewall Premium, Private DNS Resolver, Bastion and global hub-to-hub peering. IPAM (`/8 -> /12 -> /16 -> /24`) is topology-agnostic.

## Consequences
- Platform team owns route tables and peering flags (automated in Day 2 vending).
- Migration to vWAN later = new hubs + re-connection of spokes; address plan unchanged.

## Revisit when
A third region is approved, spokes exceed ~50, or an SD-WAN programme starts - all three are explicit tipping points (docs/03).
