# -----------------------------------------------------------------------------
# Terraform Stack "alz" - components
#
# The SAME modules used by the root modules (GitHub Actions, Azure DevOps,
# HCP Terraform workspaces) - no logic is duplicated for Stacks.
# Dependency platform -> workloads is inferred from component references;
# values only known after apply (e.g. firewall IPs) are handled by Stacks'
# deferred changes.
# -----------------------------------------------------------------------------

component "platform" {
  source = "../../modules/platform-landing-zone"

  inputs = {
    root_parent_management_group_id    = var.root_parent_management_group_id
    platform_subscription_ids          = var.platform_subscription_ids
    architecture_name                  = var.architecture_name
    management_group_id_prefix         = var.management_group_id_prefix
    regions                            = var.regions
    organization_supernet              = var.organization_supernet
    connectivity_type                  = var.connectivity_type
    connectivity_features              = var.connectivity_features
    log_analytics_retention_in_days    = var.log_analytics_retention_in_days
    sentinel_enabled                   = var.sentinel_enabled
    security_contact_email             = var.security_contact_email
    policy_enforcement_phase           = var.policy_enforcement_phase
    allowed_locations                  = var.allowed_locations
    platform_operators_group_object_id = var.platform_operators_group_object_id
    tags                               = var.tags
  }

  providers = {
    alz                  = provider.alz.this
    azapi                = provider.azapi.management
    azapi.connectivity   = provider.azapi.connectivity
    azurerm              = provider.azurerm.management
    azurerm.connectivity = provider.azurerm.connectivity
    modtm                = provider.modtm.this
    random               = provider.random.this
    time                 = provider.time.this
  }
}

component "workloads" {
  source = "../../modules/workload-vending"

  inputs = {
    platform = {
      connectivity_type                = component.platform.connectivity_type
      primary_location                 = component.platform.primary_location
      management_group_resource_ids    = component.platform.management_group_resource_ids
      management_group_ids             = component.platform.management_group_ids
      ipam_plan                        = component.platform.ipam_plan
      log_analytics_workspace_id       = component.platform.log_analytics_workspace_id
      dns_server_ip_addresses          = component.platform.dns_server_ip_addresses
      firewall_private_ip_addresses    = component.platform.firewall_private_ip_addresses
      hub_virtual_network_resource_ids = component.platform.hub_virtual_network_resource_ids
      virtual_hub_resource_ids         = component.platform.virtual_hub_resource_ids
      private_dns_zone_resource_ids    = component.platform.private_dns_zone_resource_ids
    }
    subscription_billing_scope = var.subscription_billing_scope
    workload_landing_zones     = var.workload_landing_zones
    budget_start_date          = var.budget_start_date
    hub_gateways_present       = var.hub_gateways_present
    policy_enforcement_phase   = var.policy_enforcement_phase
    allowed_service_endpoints  = var.allowed_service_endpoints
    tags                       = var.tags
  }

  providers = {
    azapi                = provider.azapi.management
    azurerm              = provider.azurerm.management
    azurerm.connectivity = provider.azurerm.connectivity
    modtm                = provider.modtm.this
    random               = provider.random.this
    time                 = provider.time.this
  }
}
