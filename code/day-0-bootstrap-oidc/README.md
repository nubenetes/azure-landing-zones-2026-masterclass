# Day 0 - Bootstrap: Remote State & Workload Identity Federation

> **Note**: This architectural reference framework and repository content were fully generated using **Claude Opus 5.5**. Untested reference - see the [disclaimer](../../README.md).

Creates the trust anchors that every later stage depends on. Run **once**, locally, by a PIM-elevated platform engineer.

## What it creates

| Resource | Purpose | Hardening |
|---|---|---|
| `rg-<prefix>-iac-state-<region>` | Holds state resources | `CanNotDelete` lock |
| Key Vault (Premium, RBAC) + `cmk-tfstate` (RSA-HSM 4096) | Customer-managed key for state encryption | Purge protection, 90-day soft delete, automatic rotation, firewall to operator IPs |
| User-assigned identity `id-<prefix>-tfstate-cmk` | Lets Storage wrap/unwrap the CMK | `Key Vault Crypto Service Encryption User` only |
| Storage account (GZRS) + containers `tfstate-bootstrap`, `tfstate-platform`, `tfstate-workloads` | Terraform remote state | Shared Key **disabled**, Entra-only, TLS 1.2, infra encryption, versioning, change feed, 30-day soft delete, `prevent_destroy` |
| App registration + SP **plan** | PR / main plans, drift detection | OIDC subjects `pull_request` and `ref:refs/heads/main`; `Reader` + `Storage Blob Data Reader` |
| App registration + SP **apply** | Environment-gated applies | OIDC subject `environment:production` only; `Owner` **with ABAC condition** + `Storage Blob Data Contributor` |

## Steps

```bash
# 1. Authenticate (activate PIM role first)
az login --tenant <tenant-id>

# 2. Configure
cp terraform.tfvars.example terraform.tfvars   # edit values

# 3. Create (local state for now)
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 4. Migrate bootstrap state into the account it created
terraform output -raw backend_hcl > ../backend.hcl     # edit container_name -> tfstate-bootstrap
#    uncomment  backend "azurerm" {}  in terraform.tf, then:
terraform init -migrate-state \
  -backend-config=../backend.hcl \
  -backend-config="container_name=tfstate-bootstrap" \
  -backend-config="key=day-0-bootstrap-oidc.tfstate"
rm -f terraform.tfstate terraform.tfstate.backup      # after verifying the remote copy

# 5. Configure GitHub (identifiers only - no secrets)
terraform output -raw github_configuration_commands | bash
```

Then, in GitHub: add **required reviewers** to the `production` environment and protect `main`.

## Required permissions for the operator

| Scope | Role | Why |
|---|---|---|
| Tenant Root Group (or root parent MG) | Owner *or* User Access Administrator + Contributor | Assign Reader / Owner to the CI identities |
| Entra ID | Application Developer (or Cloud Application Administrator) | Create app registrations and federated credentials |
| Bootstrap subscription | Contributor + User Access Administrator | Create state resources and data-plane role assignments |

> [!WARNING]
> `operator_ip_cidrs` locks the Key Vault firewall to your egress IPs. If it is left empty the vault stays reachable from any network (still RBAC-protected) - acceptable only in a sandbox.

> [!NOTE]
> GitHub-hosted runners use dynamic IPs, so the state account keeps public network access enabled while relying on Entra-only authentication. For full network isolation, use VNet-injected or self-hosted runners and set `state_storage_public_network_access_enabled = false` (add a Private Endpoint for `blob`).
