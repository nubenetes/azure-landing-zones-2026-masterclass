###############################################################################
# Day 0 (optional) - Azure DevOps delivery: input variables
###############################################################################

variable "organization_url" {
  type        = string
  description = "Azure DevOps organisation URL, e.g. https://dev.azure.com/nubenetes."
}

variable "project_name" {
  type        = string
  description = "Existing Azure DevOps project that hosts the ALZ pipelines."
  default     = "azure-landing-zones"
}

variable "tenant_id" {
  type        = string
  description = "Microsoft Entra ID tenant ID."
}

variable "root_parent_management_group_id" {
  type        = string
  description = "Scope of the service connections (management group under which the ALZ hierarchy lives)."
}

variable "root_parent_management_group_name" {
  type        = string
  description = "Display name of that management group (required by the service connection API)."
  default     = "Tenant Root Group"
}

variable "plan_client_id" {
  type        = string
  description = "Client ID of the read-only plan app registration (Day 0 output plan_identity.client_id)."
}

variable "apply_client_id" {
  type        = string
  description = "Client ID of the privileged apply app registration (Day 0 output apply_identity.client_id)."
}

variable "bootstrap_subscription_id" {
  type        = string
  description = "Subscription that hosts the Terraform state (ARM_SUBSCRIPTION_ID for the pipelines)."
}

variable "state_resource_group_name" {
  type        = string
  description = "Day 0 output state_resource_group_name."
}

variable "state_storage_account_name" {
  type        = string
  description = "Day 0 output state_storage_account_name."
}

variable "repository" {
  type = object({
    type                  = string # "GitHub" or "TfsGit" (Azure Repos)
    id                    = string # "nubenetes/azure-landing-zones-2026-masterclass" or the Azure Repos repository name
    branch                = optional(string, "refs/heads/main")
    service_connection_id = optional(string) # GitHub service connection (repo_type = GitHub)
  })
  description = "Where the pipelines' YAML lives: the GitHub repository (through a GitHub service connection) or an Azure Repos mirror."
  default = {
    type = "GitHub"
    id   = "nubenetes/azure-landing-zones-2026-masterclass"
  }

  validation {
    condition     = contains(["GitHub", "TfsGit"], var.repository.type)
    error_message = "repository.type must be GitHub or TfsGit."
  }
}

variable "approver_ids" {
  type        = list(string)
  description = "Azure DevOps identity descriptors/IDs (users or groups) that must approve production applies."
}

variable "environment_name" {
  type        = string
  description = "Azure DevOps environment that gates applies (must match the pipelines' `environment` parameter)."
  default     = "alz-production"
}

variable "service_connection_names" {
  type = object({
    plan  = optional(string, "sc-alz-plan")
    apply = optional(string, "sc-alz-apply")
  })
  description = "Names of the two service connections (must match the pipelines' parameters)."
  default     = {}
}
