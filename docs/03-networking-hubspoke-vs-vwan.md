# 03 - Network Topology: Hub-and-Spoke vs Azure Virtual WAN, IPAM, DNS & Egress

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**.

> **Disclaimer**: This repository serves purely as an advanced theoretical and architectural reference framework incorporating the latest 2026 Microsoft Azure Landing Zone best practices. The code, Terraform manifests, and pipeline configurations provided herein **have not been physically deployed, executed, or tested in a live production environment**. Users should thoroughly validate, plan, and test all code in a sandbox environment prior to enterprise implementation.

---

> 🧭 **Navigation**: [🏠 Masterclass Portal](../README.md) | [⬅️ Previous: 02. IaC Provider Matrix](02-iac-provider-matrix.md) | [➡️ Next: 04. PaaS Network Security](04-security-private-vs-service.md)

> 🎥 **Multimedia Sessions & Video Guides**:
> - 📽️ [**Azure Hub-and-Spoke vs Virtual WAN: 2026 Enterprise Network Architecture**](https://www.youtube.com/watch?v=mUmga-Nz6cc) (`8:11`, 🇬🇧 English CC 20+) — *In-depth trade-off analysis: customer-managed Hub-and-Spoke vs. Microsoft-managed vWAN, routing intents, and IPAM.*

---

## 1. The two supported topologies

Both are first-class in the ALZ accelerator and in this repository; you switch with one variable:

```hcl
connectivity_type = "hub_and_spoke_vnet" # or "virtual_wan"
```

### 1.1 Customer-managed hub-and-spoke

```mermaid
flowchart LR
    onprem["On-premises / branches"]
    subgraph weu["West Europe - 10.0.0.0/12"]
        subgraph hub1["vnet-hub-westeurope 10.0.0.0/22"]
            fw1["Azure Firewall Premium<br/>DNS proxy"]
            gw1["ER / VPN gateway"]
            pdr1["Private DNS Resolver<br/>inbound endpoint"]
            bas1["Bastion"]
        end
        s1["vnet-payments-prod<br/>10.2.0.0/24"]
        s2["vnet-payments-nonprod<br/>10.3.0.0/24"]
    end
    subgraph neu["North Europe - 10.16.0.0/12"]
        subgraph hub2["vnet-hub-northeurope 10.16.0.0/22"]
            fw2["Azure Firewall Premium"]
            pdr2["Private DNS Resolver"]
        end
        s3["vnet-genai-assistant-prod<br/>10.20.1.0/24"]
    end
    dns[("Central privatelink.* zones<br/>rg-hub-dns (Connectivity)")]
    onprem <--> gw1
    s1 <-- "peering + UDR 0/0 -> FW" --> hub1
    s2 <-- "peering + UDR 0/0 -> FW" --> hub1
    s3 <-- "peering + UDR 0/0 -> FW" --> hub2
    hub1 <-- "global hub-to-hub peering<br/>(routes for each /12)" --> hub2
    pdr1 & pdr2 --- dns
```

You own: route tables, firewall placement, peering, gateway transit, BGP propagation. Microsoft owns: the individual managed services.

### 1.2 Microsoft-managed Azure Virtual WAN

```mermaid
flowchart LR
    onprem["On-premises / SD-WAN branches / P2S users"]
    subgraph vwan["vwan-westeurope (Standard)"]
        direction LR
        subgraph vh1["vhub-westeurope 10.0.0.0/23"]
            sfw1["Secured hub firewall<br/>routing intent: Internet + Private"]
            er1["ER / S2S / P2S gateways"]
        end
        subgraph vh2["vhub-northeurope 10.16.0.0/23"]
            sfw2["Secured hub firewall"]
        end
        vh1 <-- "Microsoft global transit" --> vh2
    end
    side1["Sidecar VNet 10.0.2.0/24<br/>Private DNS Resolver + Bastion"]
    a["Spoke VNets (corp/online)"] -- "VNet connection<br/>secure_internet + secure_private" --> vh1
    b["Spoke VNets"] -- "VNet connection" --> vh2
    side1 -- "VNet connection" --> vh1
    onprem <--> er1
```

Routing intent sends all internet and private traffic through the secured-hub firewall; you do not author UDRs. Services that cannot live inside a virtual hub (Private DNS Resolver, Bastion) live in a **sidecar VNet** connected to the hub.

---

## 2. Decision matrix (12 criteria)

| # | Criterion | Hub-and-spoke (customer-managed) | Virtual WAN (Microsoft-managed) |
|---|---|---|---|
| 1 | **Regional footprint** | Ideal for **1-2 regions**; hub-to-hub peering and route tables grow manually per region | Ideal for **3+ regions**; any-to-any transit across hubs out of the box |
| 2 | **Spoke scale** | Comfortable up to ~**40-50 spokes per hub**; hard limit is the VNet peering limit (500 by default) and UDR/route sprawl | **50+ spokes**; hundreds of VNet connections per hub, capacity scaled through routing infrastructure units |
| 3 | **Transit & routing control** | Full control: UDRs, BGP propagation per route table, custom next hops, forced tunnelling exactly as designed | Routing intent & route maps; powerful but opinionated - some custom patterns are not expressible |
| 4 | **NVA support** | Any NVA, any HA pattern (ILB sandwich, Gateway Load Balancer, active/active) | Integrated NVAs from supported partners inside the hub, or NVAs in a spoke with routing intent/BGP peering; fewer patterns |
| 5 | **Hybrid connectivity** | ExpressRoute and VPN gateways you size and operate; branch-to-branch requires extra design | Native S2S/P2S/ER aggregation, **SD-WAN partner automation**, branch-to-branch built in |
| 6 | **Security inspection** | Azure Firewall or NVA in the hub; east-west via UDR | Secured virtual hub (Azure Firewall or SaaS/NVA) with routing intent for internet **and** private traffic |
| 7 | **DNS** | Firewall DNS proxy -> Private DNS Resolver in the hub VNet | Resolver in a sidecar VNet; firewall DNS proxy optional |
| 8 | **Base cost** | **Lower** - you pay for gateways, firewall and peering data transfer; no hub fee | Higher fixed cost - **per-hub hourly fee** plus hub data processing, on top of firewall/gateways |
| 9 | **Data-path cost** | Peering ingress/egress charges per GB on both sides | Hub data processing per GB + connection charges; often cheaper than mesh peering at large scale |
| 10 | **Operational complexity** | Higher at scale (routes, peerings, gateway transit flags per spoke) | Lower day-2 toil at scale; less low-level visibility and fewer knobs |
| 11 | **Change velocity** | Any feature as soon as GA in VNets | Some features arrive later in vWAN hubs; check support matrix before committing |
| 12 | **Migration / reversibility** | Moving to vWAN later is a planned re-connection of spokes (address plan in this repo is compatible) | Moving back is harder (hub address prefixes, routing intent, sidecar patterns) |

### Tipping point

```mermaid
flowchart TD
    A{"3+ regions?"} -- yes --> V["Virtual WAN"]
    A -- no --> B{"> 50 spokes expected<br/>within 24 months?"}
    B -- yes --> V
    B -- no --> C{"Heavy SD-WAN / branch-to-branch<br/>or global transit?"}
    C -- yes --> V
    C -- no --> D{"Custom NVA chains or<br/>non-standard routing required?"}
    D -- yes --> H["Hub-and-spoke"]
    D -- no --> H2["Hub-and-spoke (lower base cost)<br/>re-evaluate yearly"]
```

> [!NOTE]
> **Tipping point: 3+ regions or more than ~50 spoke VNets.** Below it, hub-and-spoke is usually cheaper and more flexible. Above it, vWAN's managed transit removes most of the routing toil. The IPAM below is identical for both, so the decision is reversible in planning terms.

### Indicative cost anchors

> [!CAUTION]
> List prices change and differ by region and agreement. The figures below are **indicative pay-as-you-go anchors for orientation only**; always confirm with the [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/).

| Component | Indicative order of magnitude |
|---|---|
| Virtual WAN Standard hub | ~USD 0.25 per hub-hour (~USD 180/month) + ~USD 0.02 per GB processed |
| Azure Firewall Standard / Premium | ~USD 1.25 / ~USD 1.75 per deployment-hour + per-GB processing |
| VNet peering (intra-region) | ~USD 0.01 per GB in **and** out |
| Private Endpoint | ~USD 0.01 per endpoint-hour + ~USD 0.01 per GB (see docs/04) |

---

## 3. IP Address Management (IPAM)

### 3.1 The hierarchy

| Level | Size | Rule | Example (primary region, index 0) |
|---|---|---|---|
| Organisation | `/8` | One non-overlapping RFC 1918 supernet, reserved in the enterprise IPAM | `10.0.0.0/8` |
| Region | `/12` | `cidrsubnet(/8, 4, region.index)` - 16 regions max | `10.0.0.0/12` |
| Archetype + environment (MG/env) | `/16` | `cidrsubnet(/12, 4, block_index)` | corp-prod `10.2.0.0/16` |
| Workload spoke | `/24` | `cidrsubnet(/16, 8, spoke_index)` - 256 spokes per archetype/env/region | `10.2.0.0/24` |
| Subnets | `/25`-`/27` | fixed layout per spoke | app `.0/25`, PE `.128/26`, integration `.192/27` |

### 3.2 Block allocation inside each regional `/12`

| Block index | Purpose | Primary (`10.0.0.0/12`) | Secondary (`10.16.0.0/12`) |
|---|---|---|---|
| 0 | Connectivity hub | `10.0.0.0/16` | `10.16.0.0/16` |
| 1 | Identity | `10.1.0.0/16` | `10.17.0.0/16` |
| 2 | Corp - prod | `10.2.0.0/16` | `10.18.0.0/16` |
| 3 | Corp - nonprod | `10.3.0.0/16` | `10.19.0.0/16` |
| 4 | Online - prod | `10.4.0.0/16` | `10.20.0.0/16` |
| 5 | Online - nonprod | `10.5.0.0/16` | `10.21.0.0/16` |
| 6-14 | Reserved (AI/data platforms, new archetypes, AKS pod CIDRs) | `10.6-10.14.0.0/16` | `10.22-10.30.0.0/16` |
| 15 | Sandbox (never peered, still unique) | `10.15.0.0/16` | `10.31.0.0/16` |

### 3.3 Hub layouts

| Hub-and-spoke (`/22` inside the hub `/16`) | Prefix | Virtual WAN | Prefix |
|---|---|---|---|
| `AzureFirewallSubnet` | `10.0.0.0/26` | Virtual hub address prefix | `10.0.0.0/23` |
| `AzureBastionSubnet` | `10.0.0.64/26` | Sidecar VNet | `10.0.2.0/24` |
| `GatewaySubnet` | `10.0.0.128/27` | Resolver inbound subnet (sidecar) | `10.0.2.0/28` |
| Resolver inbound subnet | `10.0.0.160/28` | Bastion subnet (sidecar) | `10.0.2.64/26` |
| `AzureFirewallManagementSubnet` | `10.0.0.192/26` | | |

All of this is computed in [`locals.tf`](../code/modules/platform-landing-zone/locals.tf) and exported as the `ipam_plan` output that Day 2 consumes - **no spreadsheet, no manual allocation, no overlap**. Uniqueness of `(region, archetype, environment, spoke_index)` is enforced by a variable validation in Day 2.

> [!TIP]
> If you already run **Azure Virtual Network Manager IPAM pools**, the Day 2 vending module also accepts `ipam_pools` instead of `address_space`; keep the same block structure as the pool hierarchy.

---

## 4. Private DNS and egress

### 4.1 Name resolution path (hub-and-spoke)

```mermaid
sequenceDiagram
    participant VM as Workload (spoke)
    participant FW as Azure Firewall (DNS proxy)
    participant PDR as Private DNS Resolver (inbound)
    participant Z as privatelink.blob.core.windows.net (central zone)
    participant PUB as Azure public DNS
    VM->>FW: resolve stpayments.blob.core.windows.net
    FW->>PDR: forward (spoke DNS server = firewall IP)
    PDR->>Z: zone linked to hub VNet
    alt private endpoint record exists
        Z-->>VM: 10.2.0.140 (Private Endpoint)
    else no record
        PDR->>PUB: recursive resolution
        PUB-->>VM: public IP (blocked by Deny-Public-Endpoints in corp)
    end
```

Key properties:

- **Zones are central** (Connectivity subscription, `rg-hub-dns-<region>`). Spokes never host `privatelink.*` zones (`Audit-PeDnsZones` flags violations).
- **Records are automatic**: the `Deploy-Private-DNS-Zones` DINE assignment at `corp` writes the Private Endpoint A-record into the central zone.
- **Firewall as DNS proxy** gives FQDN-based network rules a consistent view of name resolution.
- **On-premises** forwards Azure private zones to the resolver inbound endpoint; Azure forwards on-prem zones through an outbound endpoint + forwarding ruleset.
- **DNS Security Policy** (`dns_security_policy = true`) adds DNS-layer filtering/logging on the hub VNet.

### 4.2 Egress

| Topology | Mechanism | Configured by |
|---|---|---|
| Hub-and-spoke | UDR `0.0.0.0/0 -> Azure Firewall private IP`, BGP propagation disabled on spoke route tables | Day 2 vending (`rt-<lz>`) |
| Virtual WAN | Routing intent (internet + private) on the secured hub | Day 2 vending (`vwan_security_configuration`) |
| Both | **Private subnets** (`default_outbound_access_enabled = false`) - no implicit outbound IPs | Day 1 hub subnets, Day 2 spoke subnets, ALZ `Enforce-Subnet-Private` |

> [!IMPORTANT]
> New VNets created with API versions released after 31 March 2026 are private-subnet by default. Workloads that silently relied on default outbound access must use the firewall (or an explicit NAT Gateway in documented exceptions).

---

## References

- ALZ Terraform scenarios (hub-and-spoke vs vWAN, single/multi region): <https://azure.github.io/Azure-Landing-Zones/accelerator/starter-terraform/scenarios/>
- ALZ IP address customisation: <https://azure.github.io/Azure-Landing-Zones/accelerator/starter-terraform/options/ip-addresses/>
- Default outbound access: <https://learn.microsoft.com/azure/virtual-network/ip-services/default-outbound-access>
- Virtual WAN pricing concepts: <https://learn.microsoft.com/azure/virtual-wan/pricing-concepts>
- Azure Private Link pricing: <https://azure.microsoft.com/pricing/details/private-link/>
