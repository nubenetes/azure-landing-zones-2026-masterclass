###############################################################################
# Day 0 - Bootstrap: input variables
###############################################################################

variable "tenant_id" {
  type        = string
  description = "Microsoft Entra ID tenant ID that hosts the landing zone."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "bootstrap_subscription_id" {
  type        = string
  description = "Subscription that hosts the IaC state resources. CAF recommends the Management platform subscription."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.bootstrap_subscription_id))
    error_message = "bootstrap_subscription_id must be a GUID."
  }
}

variable "root_parent_management_group_id" {
  type        = string
  description = <<-EOT
    ID (name) of the management group under which the ALZ intermediate root will be created.
    Usually the Tenant Root Group (equal to the tenant ID). The CI/CD identities receive their
    RBAC at this scope so that Day 1 can create the hierarchy beneath it.
  EOT
}

variable "location" {
  type        = string
  description = "Azure region for the bootstrap resources (state storage, Key Vault, identities)."
  default     = "westeurope"
}

variable "name_prefix" {
  type        = string
  description = "Short lowercase prefix (3-6 chars) used to build globally unique names, e.g. 'nbn'."
  default     = "nbn"

  validation {
    condition     = can(regex("^[a-z0-9]{3,6}$", var.name_prefix))
    error_message = "name_prefix must be 3-6 lowercase alphanumeric characters."
  }
}

#------------------------------------------------------------------------------
# Delivery platforms (one or several can be enabled side by side)
#------------------------------------------------------------------------------

variable "github_enabled" {
  type        = bool
  description = "Trust GitHub Actions OIDC tokens (plan: pull_request + default branch; apply: protected environment)."
  default     = true
}

variable "hcp_terraform" {
  type = object({
    hostname     = optional(string, "app.terraform.io") # Terraform Enterprise: your TFE hostname
    organization = string
    project      = optional(string, "azure-landing-zones")
    workspaces   = optional(list(string), ["alz-platform", "alz-workloads"])
    stack = optional(object({
      name        = optional(string, "alz")
      deployments = optional(list(string), ["sandbox", "production"])
    }))
  })
  description = <<-EOT
    Trust HCP Terraform (SaaS) or Terraform Enterprise (self-managed) workload identity tokens.
    Workspaces get run-phase-specific credentials (plan -> plan identity, apply -> apply identity).
    Set `stack` to also trust Terraform Stacks deployments. Leave null to disable.
    Azure DevOps credentials are created by code/azure-devops/bootstrap instead.
  EOT
  default     = null

  validation {
    condition = var.hcp_terraform == null ? true : alltrue([
      for dep in try(var.hcp_terraform.stack.deployments, []) :
      length("organization:${var.hcp_terraform.organization}:project:${var.hcp_terraform.project}:stack:${var.hcp_terraform.stack.name}:deployment:${dep}:operation:apply") <= 127
    ])
    error_message = "HCP Terraform Stacks subjects are limited to 127 characters - shorten the organization, project, stack or deployment names."
  }
}

variable "github_organization" {
  type        = string
  description = "GitHub organization that owns the IaC repository."
  default     = "nubenetes"
}

variable "github_repository" {
  type        = string
  description = "GitHub repository name (without the organization)."
  default     = "azure-landing-zones-2026-masterclass"
}

variable "github_default_branch" {
  type        = string
  description = "Protected default branch whose pushes trigger the apply workflow."
  default     = "main"
}

variable "github_apply_environment" {
  type        = string
  description = <<-EOT
    Name of the GitHub Environment (with required reviewers) used by apply jobs.
    The apply identity ONLY trusts tokens whose subject is this environment, so an
    apply can never run without passing the environment protection rules.
  EOT
  default     = "production"
}

variable "state_containers" {
  type        = set(string)
  description = "Blob containers to create for state. One container per lifecycle stage keeps blast radius small."
  default     = ["tfstate-bootstrap", "tfstate-platform", "tfstate-workloads"]
}

variable "operator_ip_cidrs" {
  type        = list(string)
  description = <<-EOT
    Public IP ranges (CIDR) of the operators running Day 0 locally. When non-empty, the Key Vault
    firewall defaults to Deny and only these ranges (plus trusted Azure services) are allowed.
  EOT
  default     = []
}

variable "state_storage_public_network_access_enabled" {
  type        = bool
  description = <<-EOT
    GitHub-hosted runners egress from a large, changing IP pool, so the state account must accept
    public network traffic (protected by Entra ID-only auth + RBAC) unless you use self-hosted
    runners or private networking for runners. Set to false when runners reach the account through
    a Private Endpoint.
  EOT
  default     = true
}

variable "apply_identity_rbac_condition_enabled" {
  type        = bool
  description = <<-EOT
    Attach an Azure ABAC delegation condition to the apply identity's Owner assignment so that it
    can never grant or remove Owner, User Access Administrator or Role Based Access Control
    Administrator. Strongly recommended; disable only if a downstream stage legitimately needs
    to assign one of those roles (it should not - use PIM instead).
  EOT
  default     = true
}

variable "key_rotation_period" {
  type        = string
  description = "ISO 8601 duration after which the state CMK is automatically rotated."
  default     = "P180D"
}

variable "additional_state_readers" {
  type        = map(string)
  description = "Optional map of description => Entra object ID granted 'Storage Blob Data Reader' on all state containers (e.g. a FinOps or audit group)."
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every bootstrap resource."
  default = {
    workload     = "alz-iac-bootstrap"
    managed_by   = "terraform"
    generated_by = "claude-opus-5.5"
    tested       = "false"
  }
}
