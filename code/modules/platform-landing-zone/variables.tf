###############################################################################
# Module: platform-landing-zone - input variables
###############################################################################

#------------------------------------------------------------------------------
# Tenant, subscriptions and placement
#------------------------------------------------------------------------------

variable "root_parent_management_group_id" {
  type        = string
  description = "Management group under which the ALZ intermediate root is created (usually the Tenant Root Group, i.e. the tenant ID)."
}

variable "platform_subscription_ids" {
  type = object({
    management   = string
    connectivity = string
    identity     = string
    security     = optional(string)
  })
  description = <<-EOT
    Pre-existing platform subscriptions (create them via billing/vending beforehand).
    `security` is optional: the 2026 ALZ reference architecture adds a Security management
    group under Platform for SOC tooling (Sentinel, Defender exports). If omitted, the
    management group is still created but no subscription is placed in it.
  EOT

  validation {
    condition = alltrue([
      for id in compact([
        var.platform_subscription_ids.management,
        var.platform_subscription_ids.connectivity,
        var.platform_subscription_ids.identity,
        try(var.platform_subscription_ids.security, ""),
      ]) : can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", id))
    ])
    error_message = "Every platform subscription ID must be a GUID."
  }
}

variable "architecture_name" {
  type        = string
  description = "Name of the architecture definition in ./lib/architecture_definitions to deploy."
  default     = "alz_2026_masterclass"
}

variable "management_group_id_prefix" {
  type        = string
  description = <<-EOT
    Prefix applied to every management group ID. Keep "" for the production hierarchy. Use
    "canary-" together with architecture_name = "alz_2026_masterclass_canary" for an isolated
    canary hierarchy in the same tenant (CAF-recommended way to test platform changes).
  EOT
  default     = ""

  validation {
    condition     = can(regex("^[a-z0-9-]{0,12}$", var.management_group_id_prefix))
    error_message = "management_group_id_prefix must be 0-12 lowercase letters, digits or hyphens."
  }
}

#------------------------------------------------------------------------------
# Regions & IP address management (IPAM)
#------------------------------------------------------------------------------

variable "regions" {
  type = map(object({
    location     = string
    short_name   = string
    index        = number # Position of the region's /12 inside the organisation /8
    is_primary   = optional(bool, false)
    firewall_sku = optional(string, "Premium")
  }))
  description = <<-EOT
    Regions that host a connectivity hub. Each region receives a deterministic /12 carved out of
    `organization_supernet` (index 0 => 10.0.0.0/12, index 1 => 10.16.0.0/12, ...). Within that
    /12 the first /16 is reserved for the connectivity hub and the remaining /16 blocks are
    allocated to workload landing zones by Day 2 subscription vending.
  EOT

  validation {
    condition     = length([for r in values(var.regions) : r if r.is_primary]) == 1
    error_message = "Exactly one region must be marked is_primary = true."
  }

  validation {
    condition     = alltrue([for r in values(var.regions) : r.index >= 0 && r.index < 16])
    error_message = "Region index must be between 0 and 15 (sixteen /12 blocks in a /8)."
  }

  validation {
    condition     = alltrue([for r in values(var.regions) : contains(["Basic", "Standard", "Premium"], r.firewall_sku)])
    error_message = "firewall_sku must be Basic, Standard or Premium."
  }
}

variable "organization_supernet" {
  type        = string
  description = "Organisation-wide, non-overlapping RFC 1918 supernet (a /8)."
  default     = "10.0.0.0/8"

  validation {
    condition     = can(cidrhost(var.organization_supernet, 0)) && endswith(var.organization_supernet, "/8")
    error_message = "organization_supernet must be a valid /8 CIDR block."
  }
}

#------------------------------------------------------------------------------
# Connectivity
#------------------------------------------------------------------------------

variable "connectivity_type" {
  type        = string
  description = <<-EOT
    Network topology: "hub_and_spoke_vnet" (customer-managed hub, recommended for 1-2 regions
    and < ~50 spokes) or "virtual_wan" (Microsoft-managed hubs, recommended for 3+ regions,
    50+ spokes, global transit or heavy SD-WAN/branch integration). See docs/03.
  EOT
  default     = "hub_and_spoke_vnet"

  validation {
    condition     = contains(["hub_and_spoke_vnet", "virtual_wan"], var.connectivity_type)
    error_message = "connectivity_type must be hub_and_spoke_vnet or virtual_wan."
  }
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
  description = "Feature toggles for the connectivity hubs. Gateways default to off because they are the longest-running and most expensive resources to iterate on."
  default     = {}
}

#------------------------------------------------------------------------------
# Management (logging & monitoring)
#------------------------------------------------------------------------------

variable "log_analytics_retention_in_days" {
  type        = number
  description = "Interactive retention for the central Log Analytics workspace."
  default     = 90

  validation {
    condition     = var.log_analytics_retention_in_days >= 30 && var.log_analytics_retention_in_days <= 730
    error_message = "Retention must be between 30 and 730 days."
  }
}

variable "sentinel_enabled" {
  type        = bool
  description = "Onboard Microsoft Sentinel on the central workspace."
  default     = false
}

variable "security_contact_email" {
  type        = string
  description = "Defender for Cloud security contact (used by the Deploy-MDFC-Config policy assignment)."
}

#------------------------------------------------------------------------------
# Governance (Policy-as-Code)
#------------------------------------------------------------------------------

variable "policy_enforcement_phase" {
  type        = string
  description = <<-EOT
    Rollout phase for the curated set of Deny and DeployIfNotExists assignments (see docs/06):
      "audit"     - Deny and DINE assignments set to DoNotEnforce (compliance data only).
      "remediate" - DINE/Modify enforced (+ remediation tasks); Deny still DoNotEnforce.
      "enforce"   - Everything enforced (the Microsoft default for greenfield tenants).
  EOT
  default     = "enforce"

  validation {
    condition     = contains(["audit", "remediate", "enforce"], var.policy_enforcement_phase)
    error_message = "policy_enforcement_phase must be audit, remediate or enforce."
  }
}

variable "allowed_locations" {
  type        = list(string)
  description = "Optional data-residency allow-list. When non-empty an extra 'Allowed locations' assignment is added at the intermediate root via the custom library override parameters."
  default     = []
}

variable "platform_operators_group_object_id" {
  type        = string
  description = "Optional Entra ID group object ID granted standing 'Contributor' on the Platform management group. Privileged roles are expected to be activated through Entra ID PIM. Leave null to skip."
  default     = null
}

variable "enable_telemetry" {
  type        = bool
  description = "Microsoft AVM usage telemetry (modtm). Contains no customer data; see the AVM telemetry documentation."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every platform resource that supports tags."
  default = {
    managed_by   = "terraform"
    workload     = "alz-platform"
    generated_by = "claude-opus-5.5"
    tested       = "false"
  }
}
