# Hub-and-Spoke Topology (customer-managed)

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

<details>
<summary><strong>📊 Diagram: Hub-and-Spoke Topology (customer-managed)</strong> <em>(click to expand)</em></summary>

```mermaid
flowchart TB
    internet(("Internet"))
    onprem["On-premises"]
    subgraph conn["Connectivity subscription"]
        subgraph hubw["vnet-hub-westeurope 10.0.0.0/22"]
            fw["fw-hub-westeurope<br/>Premium, zones 1-3<br/>DNS proxy"]
            gw["vgw ER / VPN<br/>GatewaySubnet 10.0.0.128/27"]
            pdr["pdr-hub-westeurope<br/>inbound 10.0.0.160/28"]
            bas["bas-hub-westeurope"]
        end
        zones[("privatelink.* zones<br/>rg-hub-dns-westeurope")]
        ddos["ddos-westeurope"]
        subgraph hubn["vnet-hub-northeurope 10.16.0.0/22"]
            fw2["fw-hub-northeurope"]
            pdr2["pdr-hub-northeurope"]
        end
    end
    subgraph corp["corp MG"]
        sp1["vnet-payments-prod 10.2.0.0/24<br/>rt: 0.0.0.0/0 -> fw<br/>dns: fw IP"]
        sp2["vnet-payments-nonprod 10.3.0.0/24"]
    end
    subgraph online["online MG"]
        sp3["vnet-genai-assistant-prod 10.20.1.0/24"]
    end
    sp1 & sp2 <-->|peering| hubw
    sp3 <-->|peering| hubn
    hubw <-->|global peering| hubn
    onprem <--> gw
    fw --> internet
    fw2 --> internet
    pdr --- zones
    pdr2 --- zones
    ddos -. protects .- hubw
```

</details>

**How to read this diagram:**

- The **Connectivity subscription** holds one hub VNet per region (Azure Firewall with DNS proxy, gateways, Bastion, Private DNS Resolver) plus the shared Private Link DNS zones and the DDoS plan.
- **Spokes** (workload VNets in Corp / Online) are peered only to their regional hub and send all traffic (`0.0.0.0/0`) to the hub firewall through a route table.
- The two hubs are joined by **global peering**, so a spoke in one region reaches a spoke in the other through both firewalls.
- **Internet egress** leaves only through the firewalls; **on-premises** connects through the gateways in the primary hub.
- **Name resolution**: spokes use the firewall as DNS server, which forwards to the resolver linked to the central `privatelink.*` zones.

## ASCII

```text
                      Internet
                         ^
                         | SNAT egress (only path out)
 On-prem <==ER/VPN==> [ HUB westeurope 10.0.0.0/22 ] <==global peering==> [ HUB northeurope 10.16.0.0/22 ]
                      |  Azure Firewall (DNS proxy)                         |  Azure Firewall
                      |  Private DNS Resolver ---- central privatelink.* zones ---- Resolver
                      |  Bastion, Gateways                                  |
            peering + UDR 0/0                                      peering + UDR 0/0
            /                  \                                          |
 [corp] payments-prod     [corp] payments-nonprod               [online] genai-assistant-prod
        10.2.0.0/24              10.3.0.0/24                             10.20.1.0/24
```
