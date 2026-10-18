# OIDC CI/CD Trust Flow

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

```mermaid
flowchart LR
    subgraph gh["GitHub: nubenetes/azure-landing-zones-2026-masterclass"]
        pr["pull_request job<br/>sub: ...:pull_request"]
        mainj["main plan / drift job<br/>sub: ...:ref:refs/heads/main"]
        envj["apply job in environment 'production'<br/>(required reviewers)<br/>sub: ...:environment:production"]
    end
    subgraph entra["Microsoft Entra ID"]
        planapp["App: sp-nbn-alz-cicd-plan<br/>FIC: pull_request, ref main"]
        applyapp["App: sp-nbn-alz-cicd-apply<br/>FIC: environment:production ONLY"]
    end
    subgraph azure["Azure"]
        rootmg["Root parent MG"]
        state[("State storage<br/>Entra-only, CMK")]
    end
    pr --> planapp
    mainj --> planapp
    envj --> applyapp
    planapp -- "Reader" --> rootmg
    planapp -- "Blob Data Reader" --> state
    applyapp -- "Owner + ABAC condition<br/>(cannot assign Owner/UAA/RBAC Admin)" --> rootmg
    applyapp -- "Blob Data Contributor" --> state
```

## ASCII

```text
 GitHub job ──(1) request JWT──> token.actions.githubusercontent.com
     │  <──(2) JWT {iss, aud=api://AzureADTokenExchange, sub=repo:<org>/<repo>:<context>}──
     │
     └──(3) client_assertion=JWT, client_id=<app>──> Entra ID
                                                     │ match issuer + subject + audience
            <──────────(4) short-lived access token──┘
     ──(5) Terraform -> ARM / Storage (RBAC + ABAC evaluated)

 context = pull_request | ref:refs/heads/main      -> PLAN app  (read-only)
 context = environment:production (after approval) -> APPLY app (write, ABAC-limited)
```
