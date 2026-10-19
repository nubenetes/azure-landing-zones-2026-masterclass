# -----------------------------------------------------------------------------
# Terraform Stack "alz" - variables
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment (passes `terraform stacks validate` in CI only). Validate with
# `terraform stacks validate` and a canary deployment first.
#
# Stack variables require `type` and do not support `validation`; the
# validations live in the modules themselves.
# -----------------------------------------------------------------------------

#--- Identity (workload identity federation, no secrets) ----------------------

variable "identity_token" {
  type        = string
  description = "JWT from the deployment's identity_token block (audience api://AzureADTokenExchange)."
  ephemeral   = true
}

variable "tenant_id" {
  type        = string
  description = "Microsoft Entra ID tenant ID."
}

variable "client_id" {
  type        = string
  description = "Client ID of the Day 0 apply app; it trusts this Stack's plan and apply subjects for each deployment."
}

#--- ALZ Library source ---------------------------------------------------------

variable "alz_library_url" {
  type        = string
  description = "go-getter URL of the custom ALZ library (the module's lib folder). Pin ?ref= to a release tag."
  default     = "git::https://github.com/nubenetes/azure-landing-zones-2026-masterclass.git//code/modules/platform-landing-zone/lib?ref=main"
}

#--- Platform landing zone (component "platform") ------------------------------

variable "root_parent_management_group_id" {
  type        = string
  description = "Management group under which this deployment's hierarchy is created."
}

variable "platform_subscription_ids" {
  type = object({
    management   = string
    connectivity = string
    identity     = string
    security     = optional(string)
  })
  description = "Platform subscriptions of this deployment."
}

variable "architecture_name" {
  type        = string
  description = "alz_2026_masterclass (production) or alz_2026_masterclass_canary."
}

variable "management_group_id_prefix" {
  type        = string
  description = "\"\" for production, \"canary-\" for the canary hierarchy."
  default     = ""
}

variable "regions" {
  type = map(object({
    location     = string
    short_name   = string
    index        = number
    is_primary   = optional(bool, false)
    firewall_sku = optional(string, "Premium")
  }))
  description = "Hub regions and their /12 index."
}

variable "organization_supernet" {
  type        = string
  description = "Organisation /8."
  default     = "10.0.0.0/8"
}

variable "connectivity_type" {
  type        = string
  description = "hub_and_spoke_vnet or virtual_wan."
  default     = "hub_and_spoke_vnet"
}

variable "connectivity_features" {
  type = object({
    ddos_protection_plan      = optional(bool, true)
    firewall                  = optional(bool, true)
    bastion                   = optional(bool, true)
    vpn_gateway               = optional(bool, false)
    expressroute_gateway      = optional(bool, false)
    private_dns_zones         = optional(bool, true)
    private_dns_resolver      = optional(bool, true)
    dns_security_policy       = optional(bool, true)
    private_dns_auto_registry = optional(bool, false)
  })
  description = "Connectivity feature toggles."
  default     = {}
}

variable "log_analytics_retention_in_days" {
  type        = number
  description = "Log Analytics retention."
  default     = 90
}

variable "sentinel_enabled" {
  type        = bool
  description = "Onboard Microsoft Sentinel."
  default     = false
}

variable "security_contact_email" {
  type        = string
  description = "Defender for Cloud security contact."
}

variable "policy_enforcement_phase" {
  type        = string
  description = "audit | remediate | enforce (applies to both components)."
  default     = "audit"
}

variable "allowed_locations" {
  type        = list(string)
  description = "Data-residency allow-list."
  default     = []
}

variable "platform_operators_group_object_id" {
  type        = string
  description = "Optional Entra ID group with standing Contributor on Platform."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags for every resource."
  default     = {}
}

#--- Workload vending (component "workloads") ----------------------------------

variable "subscription_billing_scope" {
  type        = string
  description = "Billing scope for new subscription aliases."
  default     = null
}

variable "workload_landing_zones" {
  type = map(object({
    display_name             = string
    archetype                = string
    environment              = string
    region_key               = string
    spoke_index              = number
    existing_subscription_id = optional(string)
    owner_group_object_id    = string
    cost_center              = string
    budget_amount            = optional(number, 1000)
    budget_contact_emails    = list(string)
    github_repository        = optional(string)
    private_dns_zone_links   = optional(bool, false)
    expires_on               = optional(string) # YYYY-MM-DD, mandatory for sandboxes
    decommissioned           = optional(bool, false) # true = move to the decommissioned MG (Enforce-ALZ-Decomm) before removal
    tags                     = optional(map(string), {})
  }))
  description = "Subscription vending order form for this deployment."
  default     = {}
}

variable "budget_start_date" {
  type        = string
  description = "Budget evaluation start (first day of a month, RFC 3339)."
  default     = "2026-11-01T00:00:00Z"
}

variable "hub_gateways_present" {
  type        = bool
  description = "Hubs host VPN/ExpressRoute gateways."
  default     = false
}

variable "allowed_service_endpoints" {
  type        = list(string)
  description = "Approved service endpoint exceptions."
  default     = []
}
