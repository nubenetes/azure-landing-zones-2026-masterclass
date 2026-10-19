###############################################################################
# Day 2 - Workload vending & operations (root): input variables
# Everything except the "platform contract" mirrors
# ../modules/workload-vending/variables.tf - keep them in sync.
###############################################################################

#------------------------------------------------------------------------------
# Platform contract (Day 1 remote state)
#------------------------------------------------------------------------------

variable "platform_state" {
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = optional(string, "tfstate-platform")
    key                  = optional(string, "day-1-platform-landing-zone.tfstate")
  })
  description = "Azure Storage location of the Day 1 state (GitHub Actions / Azure DevOps). Ignored when hcp_platform_workspace is set. Read-only access is sufficient."
  default     = null
}

variable "hcp_platform_workspace" {
  type = object({
    hostname     = optional(string, "app.terraform.io") # or your Terraform Enterprise hostname
    organization = string
    workspace    = optional(string, "alz-platform")
  })
  description = "HCP Terraform / Terraform Enterprise workspace that holds the Day 1 state. When set (the HCP bootstrap sets it as a workspace variable), it takes precedence over platform_state. The platform workspace must share its state with this workspace."
  default     = null
}

variable "management_subscription_id" {
  type        = string
  description = "Management platform subscription (default provider context, policy assignment location)."
}

variable "connectivity_subscription_id" {
  type        = string
  description = "Connectivity platform subscription (central Private DNS zones)."
}

variable "subscription_billing_scope" {
  type        = string
  description = <<-EOT
    Billing scope used to create new subscription aliases, e.g.
      EA : /providers/Microsoft.Billing/billingAccounts/<id>/enrollmentAccounts/<id>
      MCA: /providers/Microsoft.Billing/billingAccounts/<id>/billingProfiles/<id>/invoiceSections/<id>
    The apply identity needs the matching billing role (EA "Enrollment account subscription
    creator" / MCA "Azure subscription creator") - granted outside Terraform.
  EOT
  default     = null
}

#------------------------------------------------------------------------------
# Workload landing zones (the vending "order form")
#------------------------------------------------------------------------------

variable "workload_landing_zones" {
  type = map(object({
    display_name             = string
    archetype                = string           # corp | online | sandbox
    environment              = string           # prod | nonprod
    region_key               = string           # key of the Day 1 `regions` map
    spoke_index              = number           # 0-255 => /24 slice of the archetype /16
    existing_subscription_id = optional(string) # adopt an existing subscription instead of creating one
    owner_group_object_id    = string           # Entra ID group of the workload team
    cost_center              = string
    budget_amount            = optional(number, 1000) # monthly, billing currency
    budget_contact_emails    = list(string)
    github_repository        = optional(string)      # "org/repo" of the workload's own IaC (gets an OIDC identity)
    private_dns_zone_links   = optional(bool, false) # see dns.tf - exception path only
    expires_on               = optional(string)      # YYYY-MM-DD, mandatory for sandboxes
    decommissioned           = optional(bool, false) # true = move to the decommissioned MG (Enforce-ALZ-Decomm) before removal
    tags                     = optional(map(string), {})
  }))
  description = "One entry per workload landing zone (one subscription per workload per environment)."
  default     = {}

  validation {
    condition     = alltrue([for lz in values(var.workload_landing_zones) : contains(["corp", "online", "sandbox"], lz.archetype)])
    error_message = "archetype must be corp, online or sandbox."
  }

  validation {
    condition     = alltrue([for lz in values(var.workload_landing_zones) : contains(["prod", "nonprod"], lz.environment)])
    error_message = "environment must be prod or nonprod."
  }

  validation {
    condition     = alltrue([for lz in values(var.workload_landing_zones) : lz.spoke_index >= 0 && lz.spoke_index <= 255])
    error_message = "spoke_index must be between 0 and 255 (a /24 inside the archetype's /16)."
  }

  validation {
    condition = alltrue([
      for lz in values(var.workload_landing_zones) :
      lz.archetype != "sandbox" || (lz.expires_on != null && can(regex("^\\d{4}-\\d{2}-\\d{2}$", lz.expires_on)))
    ])
    error_message = "Sandbox landing zones must set expires_on (YYYY-MM-DD): CAF requires every sandbox to have an expiration date."
  }

  validation {
    condition = length(distinct([
      for lz in values(var.workload_landing_zones) : "${lz.region_key}/${lz.archetype}/${lz.environment}/${lz.spoke_index}"
    ])) == length(var.workload_landing_zones)
    error_message = "Two workload landing zones resolve to the same address block (region/archetype/environment/spoke_index must be unique)."
  }
}

variable "budget_start_date" {
  type        = string
  description = "First day of the month (RFC 3339) from which budgets are evaluated."
  default     = "2026-11-01T00:00:00Z"
}

variable "hub_gateways_present" {
  type        = bool
  description = "Whether the hubs host VPN/ExpressRoute gateways (enables use_remote_gateways on spoke peerings)."
  default     = false
}

#------------------------------------------------------------------------------
# Day 2 governance: workload guardrails initiative
#------------------------------------------------------------------------------

variable "policy_enforcement_phase" {
  type        = string
  description = "audit | remediate | enforce - see docs/06. Controls the effects of the workload guardrails initiative and whether remediation tasks are created."
  default     = "audit"

  validation {
    condition     = contains(["audit", "remediate", "enforce"], var.policy_enforcement_phase)
    error_message = "policy_enforcement_phase must be audit, remediate or enforce."
  }
}

variable "allowed_service_endpoints" {
  type        = list(string)
  description = "Documented exceptions to the 'no service endpoints' rule, e.g. [\"Microsoft.Storage.Global\"]."
  default     = []
}

variable "defender_storage_malware_cap_gb" {
  type        = number
  description = "Defender for Storage on-upload malware scanning cap (GB/month/storage account) for workload subscriptions."
  default     = 5000
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every vended resource."
  default = {
    managed_by   = "terraform"
    vended_by    = "alz-subscription-vending"
    generated_by = "claude-opus-5.5"
    tested       = "false"
  }
}

#------------------------------------------------------------------------------
# HCP Terraform / Terraform Enterprise dynamic provider credentials
#------------------------------------------------------------------------------

variable "tfc_azure_dynamic_credentials" {
  type = object({
    default = object({
      client_id_file_path  = string
      oidc_token_file_path = string
    })
    aliases = map(object({
      client_id_file_path  = string
      oidc_token_file_path = string
    }))
  })
  description = "Populated automatically by HCP Terraform / Terraform Enterprise when TFC_AZURE_PROVIDER_AUTH=true. Leave unset elsewhere."
  default     = null
}
