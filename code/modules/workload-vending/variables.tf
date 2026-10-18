###############################################################################
# Module: workload-vending - input variables
###############################################################################

#------------------------------------------------------------------------------
# Platform contract (module input)
#------------------------------------------------------------------------------

variable "platform" {
  type = object({
    connectivity_type                = string
    primary_location                 = string
    management_group_resource_ids    = map(string)
    management_group_ids             = optional(map(string)) # role => MG ID (handles prefixed/canary hierarchies)
    ipam_plan                        = any
    log_analytics_workspace_id       = string
    dns_server_ip_addresses          = optional(any)
    firewall_private_ip_addresses    = optional(any)
    hub_virtual_network_resource_ids = optional(any)
    virtual_hub_resource_ids         = optional(any)
    private_dns_zone_resource_ids    = optional(any)
  })
  description = <<-EOT
    Day 1 platform contract (the outputs of the platform-landing-zone module). Supplied by:
      * code/day-2-workload-vending-operations - from Terraform remote state (azurerm or HCP Terraform)
      * code/hcp-terraform/stacks/alz          - directly from component.platform outputs
  EOT
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
