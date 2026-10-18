# Management Group Hierarchy (ALZ 2026)

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

```mermaid
flowchart TD
    TRG["Tenant Root Group"] --> ALZ["alz<br/>archetype: root_masterclass"]
    ALZ --> PLAT["platform<br/>archetype: platform"]
    ALZ --> LZ["landingzones - Workload Landing Zones<br/>archetype: landing_zones_masterclass"]
    ALZ --> SBX["sandbox<br/>archetype: sandbox"]
    ALZ --> DEC["decommissioned<br/>archetype: decommissioned"]
    PLAT --> IDN["identity"]
    PLAT --> MGMT["management"]
    PLAT --> CONN["connectivity"]
    PLAT --> SEC["security"]
    LZ --> CORP["corp<br/>archetype: corp_masterclass"]
    LZ --> ONL["online"]

    IDN -.- s1(["sub: identity"])
    MGMT -.- s2(["sub: management<br/>LAW, DCRs, IaC state"])
    CONN -.- s3(["sub: connectivity<br/>hubs, firewall, DNS"])
    SEC -.- s4(["sub: security (optional)"])
    CORP -.- s5(["sub: payments-prod<br/>sub: payments-nonprod"])
    ONL -.- s6(["sub: genai-assistant-prod"])
    SBX -.- s7(["sub: data-science-sandbox"])
```

## ASCII

```text
Tenant Root Group
└── alz ................................. root_masterclass (MDFC, diagnostics, data residency)
    ├── platform ........................ platform (AMA, guardrails, private subnets)
    │   ├── identity .................... [sub] identity
    │   ├── management .................. [sub] management  (Log Analytics, DCRs, IaC state)
    │   ├── connectivity ................ [sub] connectivity (hubs/vWAN, firewall, DNS, DDoS)
    │   └── security .................... [sub] security    (Sentinel, SOC tooling) - optional
    ├── landingzones (Workload LZs) ..... landing_zones_masterclass (+ Wlz-Guardrails-2026)
    │   ├── corp ........................ corp_masterclass (no public endpoints, PE DNS DINE)
    │   │   ├── [sub] payments-prod       10.2.0.0/24
    │   │   └── [sub] payments-nonprod    10.3.0.0/24
    │   └── online ...................... online
    │       └── [sub] genai-assistant-prod 10.20.1.0/24
    ├── sandbox ......................... sandbox (isolated)
    │   └── [sub] data-science-sandbox    10.15.0.0/24 (not peered)
    └── decommissioned .................. decommissioned
```
