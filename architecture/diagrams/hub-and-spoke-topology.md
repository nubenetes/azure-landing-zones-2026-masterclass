# Hub-and-Spoke Topology (customer-managed)

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

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
