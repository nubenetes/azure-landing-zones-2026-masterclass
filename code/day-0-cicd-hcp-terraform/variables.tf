###############################################################################
# Day 0 (optional) - HCP Terraform / Terraform Enterprise: input variables
###############################################################################

variable "hostname" {
  type        = string
  description = "app.terraform.io for HCP Terraform, or the Terraform Enterprise hostname (e.g. tfe.example.com). Must match hcp_terraform.hostname in Day 0."
  default     = "app.terraform.io"
}

variable "organization" {
  type        = string
  description = "HCP Terraform / TFE organization (must match Day 0)."
}

variable "project_name" {
  type        = string
  description = "Project that groups the ALZ workspaces/Stack (must match Day 0, it is part of the OIDC subject)."
  default     = "azure-landing-zones"
}

variable "delivery_model" {
  type        = string
  description = <<-EOT
    "workspaces" - two VCS-driven workspaces (alz-platform -> run trigger -> alz-workloads) running
                   the same root modules as GitHub Actions / Azure DevOps.
    "stacks"     - one Terraform Stack (code/hcp-terraform-stacks/alz) with canary + production deployments.
    "both"       - side by side (for evaluation only - never manage the same hierarchy twice).
  EOT
  default     = "workspaces"

  validation {
    condition     = contains(["workspaces", "stacks", "both"], var.delivery_model)
    error_message = "delivery_model must be workspaces, stacks or both."
  }
}

variable "vcs" {
  type = object({
    identifier                 = optional(string, "nubenetes/azure-landing-zones-2026-masterclass")
    branch                     = optional(string, "main")
    github_app_installation_id = optional(string) # HCP Terraform GitHub App (preferred on HCP)
    oauth_token_id             = optional(string) # VCS OAuth connection (TFE, GitLab, Azure Repos, Bitbucket)
  })
  description = "VCS connection for the workspaces/Stack. Provide exactly one of github_app_installation_id or oauth_token_id."
  default     = {}

  validation {
    condition     = (var.vcs.github_app_installation_id == null) != (var.vcs.oauth_token_id == null)
    error_message = "Set exactly one of vcs.github_app_installation_id or vcs.oauth_token_id."
  }
}

variable "tenant_id" {
  type        = string
  description = "Microsoft Entra ID tenant ID."
}

variable "management_subscription_id" {
  type        = string
  description = "Default ARM_SUBSCRIPTION_ID for the runs (Management subscription)."
}

variable "plan_client_id" {
  type        = string
  description = "Client ID of the read-only plan app (Day 0 output plan_identity.client_id)."
}

variable "apply_client_id" {
  type        = string
  description = "Client ID of the apply app (Day 0 output apply_identity.client_id)."
}

variable "terraform_version" {
  type        = string
  description = "Terraform version constraint for the workspaces."
  default     = "~> 1.16.0"
}

variable "agent_pool_id" {
  type        = string
  description = "Optional HCP Terraform agent pool (private networking / Terraform Enterprise isolation). Null = HCP-managed runners."
  default     = null
}

variable "health_assessments_enabled" {
  type        = bool
  description = "Continuous drift detection and continuous validation on the workspaces (requires an HCP Terraform plan that includes health assessments)."
  default     = true
}
