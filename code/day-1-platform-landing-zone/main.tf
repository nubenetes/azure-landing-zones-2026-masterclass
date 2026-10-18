###############################################################################
# Day 1 - Platform Landing Zone (Azure Verified Modules)
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment. Validate in a sandbox tenant before any real use.
#
# Composition (mirrors the Microsoft ALZ Terraform accelerator, 2026):
#
#   module.connectivity_resource_groups  avm-res-resources-resourcegroup
#   module.management                    avm-ptn-alz-management
#   module.hub_and_spoke  (count 0/1)    avm-ptn-alz-connectivity-hub-and-spoke-vnet
#   module.virtual_wan    (count 0/1)    avm-ptn-alz-connectivity-virtual-wan
#   module.alz                           avm-ptn-alz  (MGs, policy, RBAC, placement)
#
# The ALZ module is applied LAST through *_dependencies inputs so that
# DeployIfNotExists assignments never point at a workspace, DCR, identity or
# DNS zone that does not yet exist.
#
# Module versions are pinned exactly; upgrade deliberately via PR after
# reading each module's release notes.
###############################################################################

#------------------------------------------------------------------------------
# Connectivity resource groups (Connectivity subscription)
#------------------------------------------------------------------------------
module "connectivity_resource_groups" {
  source   = "Azure/avm-res-resources-resourcegroup/azurerm"
  version  = "0.4.0"
  for_each = local.connectivity_resource_groups

  name             = each.value.name
  location         = each.value.location
  enable_telemetry = var.enable_telemetry
  tags             = var.tags

  # v0.4.0+ is AzAPI-based: the Connectivity subscription context must be
  # passed through azapi (passing azurerm would silently fall back to the
  # default azapi provider, i.e. the Management subscription).
  providers = {
    azapi = azapi.connectivity
  }
}

#------------------------------------------------------------------------------
# Management: Log Analytics, AMA identity & data collection rules, Sentinel
#------------------------------------------------------------------------------
module "management" {
  source  = "Azure/avm-ptn-alz-management/azurerm"
  version = "0.9.0"

  location                        = local.primary_location
  resource_group_name             = local.management_rg_name
  resource_group_creation_enabled = true
  log_analytics_workspace_name    = local.law_name

  # Azure Automation is no longer required by ALZ (Update Manager + AMA replace it).
  automation_account_name                    = null
  linked_automation_account_creation_enabled = false

  log_analytics_workspace_retention_in_days            = var.log_analytics_retention_in_days
  log_analytics_workspace_sku                          = "PerGB2018"
  log_analytics_workspace_local_authentication_enabled = false # Entra ID-only ingestion & query
  log_analytics_workspace_internet_ingestion_enabled   = true  # Set false once AMPLS is deployed
  log_analytics_workspace_internet_query_enabled       = true

  user_assigned_managed_identities = {
    ama = {
      name = local.ama_uami_name
    }
  }

  data_collection_rules = {
    change_tracking = { name = local.dcr_names.change_tracking }
    vm_insights     = { name = local.dcr_names.vm_insights }
    defender_sql    = { name = local.dcr_names.defender_sql }
  }

  sentinel_onboarding = var.sentinel_enabled ? {} : null

  enable_telemetry = var.enable_telemetry
  tags             = var.tags
}

#------------------------------------------------------------------------------
# Connectivity option A: customer-managed hub-and-spoke
#------------------------------------------------------------------------------
module "hub_and_spoke" {
  source  = "Azure/avm-ptn-alz-connectivity-hub-and-spoke-vnet/azurerm"
  version = "0.17.7"
  count   = local.hub_and_spoke_enabled ? 1 : 0

  # Merging the RG module outputs creates an implicit dependency edge while
  # all names/IDs stay known at plan time (pattern used by the ALZ accelerator).
  hub_and_spoke_networks_settings = merge(
    {
      enabled_resources = {
        ddos_protection_plan = var.connectivity_features.ddos_protection_plan
      }
      ddos_protection_plan = {
        name                = local.ddos_name
        resource_group_name = local.ddos_rg_name
        location            = local.primary_location
      }
    },
    { resource_groups = module.connectivity_resource_groups }
  )

  hub_virtual_networks = (merge(
    {
      vnets = {
        for k, r in var.regions : k => {
          location          = r.location
          is_primary        = r.is_primary
          default_parent_id = local.hub_rg_ids[k]

          enabled_resources = {
            firewall                              = var.connectivity_features.firewall
            firewall_policy                       = var.connectivity_features.firewall
            bastion                               = var.connectivity_features.bastion
            virtual_network_gateway_express_route = var.connectivity_features.expressroute_gateway
            virtual_network_gateway_vpn           = var.connectivity_features.vpn_gateway
            private_dns_zones                     = var.connectivity_features.private_dns_zones
            private_dns_resolver                  = var.connectivity_features.private_dns_resolver
            dns_resolver_policy                   = var.connectivity_features.dns_security_policy
          }

          hub_virtual_network = {
            name                          = "vnet-hub-${r.location}"
            address_space                 = [local.hub_vnet_layout[k].vnet]
            routing_address_space         = [local.region_supernets[k]] # whole regional /12 routes via this hub
            route_table_name_firewall     = "rt-hub-fw-${r.location}"
            route_table_name_user_subnets = "rt-hub-std-${r.location}"
            mesh_peering_enabled          = true # hub-to-hub global peering for multi-region
          }

          firewall = {
            name                             = "fw-hub-${r.location}"
            sku_tier                         = r.firewall_sku
            subnet_address_prefix            = local.hub_vnet_layout[k].firewall
            management_subnet_address_prefix = local.hub_vnet_layout[k].firewall_management
            zones                            = ["1", "2", "3"]
          }

          # DNS proxy -> Private DNS Resolver inbound endpoint is configured
          # automatically by the module when firewall + resolver + zones are on.
          firewall_policy = {
            name = "afwp-hub-${r.location}"
            sku  = r.firewall_sku
          }

          virtual_network_gateways = {
            subnet_address_prefix = local.hub_vnet_layout[k].gateway
          }

          private_dns_zones = {
            parent_id                      = local.dns_rg_id
            auto_registration_zone_enabled = var.connectivity_features.private_dns_auto_registry
            auto_registration_zone_name    = "${r.location}.azure.local"
          }

          private_dns_resolver = {
            name                  = "pdr-hub-${r.location}"
            subnet_address_prefix = local.hub_vnet_layout[k].dns_resolver_inbound
          }

          bastion = {
            name                  = "bas-hub-${r.location}"
            subnet_address_prefix = local.hub_vnet_layout[k].bastion
            bastion_public_ip = {
              name = "pip-bas-hub-${r.location}"
            }
          }
        }
      }
    },
    { resource_groups = module.connectivity_resource_groups }
  )).vnets

  enable_telemetry = var.enable_telemetry
  tags             = var.tags

  providers = {
    azurerm = azurerm.connectivity
    azapi   = azapi.connectivity
  }
}

#------------------------------------------------------------------------------
# Connectivity option B: Microsoft-managed Azure Virtual WAN
#------------------------------------------------------------------------------
module "virtual_wan" {
  source  = "Azure/avm-ptn-alz-connectivity-virtual-wan/azurerm"
  version = "0.18.0"
  count   = local.virtual_wan_enabled ? 1 : 0

  virtual_wan_settings = merge(
    {
      enabled_resources = {
        ddos_protection_plan = var.connectivity_features.ddos_protection_plan
      }
      virtual_wan = {
        name                           = "vwan-${local.primary_location}"
        resource_group_name            = local.hub_rg_names[local.primary_region_key]
        location                       = local.primary_location
        type                           = "Standard"
        allow_branch_to_branch_traffic = true
      }
      ddos_protection_plan = {
        name                = local.ddos_name
        resource_group_name = local.ddos_rg_name
        location            = local.primary_location
      }
    },
    { resource_groups = module.connectivity_resource_groups }
  )

  virtual_hubs = (merge(
    {
      vhubs = {
        for k, r in var.regions : k => {
          location          = r.location
          is_primary        = r.is_primary
          default_parent_id = local.hub_rg_ids[k]

          enabled_resources = {
            firewall                              = var.connectivity_features.firewall
            firewall_policy                       = var.connectivity_features.firewall
            bastion                               = var.connectivity_features.bastion
            virtual_network_gateway_express_route = var.connectivity_features.expressroute_gateway
            virtual_network_gateway_vpn           = var.connectivity_features.vpn_gateway
            private_dns_zones                     = var.connectivity_features.private_dns_zones
            private_dns_resolver                  = var.connectivity_features.private_dns_resolver
            # vWAN hubs cannot host the resolver or Bastion: a "sidecar" VNet
            # connected to the hub carries them.
            sidecar_virtual_network = var.connectivity_features.private_dns_resolver || var.connectivity_features.bastion
          }

          hub = {
            name           = "vhub-${r.location}"
            address_prefix = local.vwan_layout[k].hub
          }

          firewall = {
            name     = "fw-vhub-${r.location}"
            sku_tier = r.firewall_sku
            zones    = [1, 2, 3]
          }

          firewall_policy = {
            name = "afwp-vhub-${r.location}"
            sku  = r.firewall_sku
          }

          private_dns_zones = {
            parent_id                      = local.dns_rg_id
            auto_registration_zone_enabled = var.connectivity_features.private_dns_auto_registry
            auto_registration_zone_name    = "${r.location}.azure.local"
          }

          private_dns_resolver = {
            name                  = "pdr-vhub-${r.location}"
            subnet_address_prefix = local.vwan_layout[k].dns_resolver_inbound
          }

          bastion = {
            name                  = "bas-vhub-${r.location}"
            subnet_address_prefix = local.vwan_layout[k].bastion
            bastion_public_ip = {
              name = "pip-bas-vhub-${r.location}"
            }
          }

          sidecar_virtual_network = {
            name          = "vnet-sidecar-${r.location}"
            address_space = [local.vwan_layout[k].sidecar_vnet]
          }
        }
      }
    },
    { resource_groups = module.connectivity_resource_groups }
  )).vhubs

  enable_telemetry = var.enable_telemetry
  tags             = var.tags

  providers = {
    azurerm = azurerm.connectivity
    azapi   = azapi.connectivity
  }
}

#------------------------------------------------------------------------------
# Governance: management groups, policy, RBAC, subscription placement
#------------------------------------------------------------------------------
module "alz" {
  source  = "Azure/avm-ptn-alz/azurerm"
  version = "0.22.0"

  architecture_name  = var.architecture_name
  parent_resource_id = var.root_parent_management_group_id
  location           = local.primary_location

  policy_default_values        = local.policy_default_values
  policy_assignments_to_modify = local.policy_assignments_to_modify

  subscription_placement            = local.subscription_placement
  management_group_role_assignments = local.management_group_role_assignments

  # Ordering without depends_on (which would make for_each keys unknown):
  # assignments and their role assignments wait for the platform resources
  # whose IDs were composed in locals.tf.
  policy_assignments_dependencies = [
    module.management,
    local.hub_and_spoke_enabled ? module.hub_and_spoke : null,
    local.virtual_wan_enabled ? module.virtual_wan : null,
  ]
  policy_role_assignments_dependencies = [
    module.management,
    local.hub_and_spoke_enabled ? module.hub_and_spoke : null,
    local.virtual_wan_enabled ? module.virtual_wan : null,
  ]

  enable_telemetry = var.enable_telemetry
}
