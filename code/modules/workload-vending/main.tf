###############################################################################
# Module: workload-vending - subscription vending (Workload Landing Zones)
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment. Validate in a sandbox tenant before any real use.
#
# Each entry of var.workload_landing_zones produces a fully governed
# Workload Landing Zone:
#   * subscription alias (or adoption of an existing subscription)
#   * placement in corp / online / sandbox management group
#   * spoke VNet carved deterministically from the Day 1 IPAM plan
#   * hub peering (hub-and-spoke) or vHub connection with routing intent (vWAN)
#   * DNS pointed at the hub (Firewall DNS proxy -> Private DNS Resolver)
#   * default route to Azure Firewall (hub-and-spoke), NSG on every subnet
#   * workload team RBAC, budget alerts, optional OIDC identity for the
#     workload's own pipeline (no secrets)
#
# Platform owns this module; workload teams submit a PR that adds one map
# entry to the caller's terraform.tfvars (separation of duties, docs/05).
# The Day 1 contract arrives through var.platform - this module never reads
# state itself, so it works unchanged as a Terraform Stacks component.
###############################################################################

locals {
  platform = var.platform

  # Role -> management group ID (identity mapping for platforms that predate
  # the management_group_ids output; prefixed IDs for canary hierarchies).
  mg_id_by_role = coalesce(local.platform.management_group_ids, {
    for role in ["alz", "landingzones", "corp", "online", "sandbox", "decommissioned"] : role => role
  })

  hub_and_spoke = local.platform.connectivity_type == "hub_and_spoke_vnet"
  virtual_wan   = local.platform.connectivity_type == "virtual_wan"

  lz = {
    for k, v in var.workload_landing_zones : k => {
      location = local.platform.ipam_plan[v.region_key].location

      # Management group placement: the archetype MG, or the decommissioned MG
      # (deny-all-new-resources) while the subscription waits for cancellation.
      mg_role = v.decommissioned ? "decommissioned" : v.archetype

      # IPAM: /16 per archetype+environment, /24 per workload spoke
      ipam_block = v.archetype == "sandbox" ? "sandbox" : "${v.archetype}-${v.environment}"
      spoke_cidr = cidrsubnet(
        local.platform.ipam_plan[v.region_key].blocks[v.archetype == "sandbox" ? "sandbox" : "${v.archetype}-${v.environment}"],
        8,
        v.spoke_index
      )

      # Sandboxes are deliberately isolated: no hub connectivity.
      connected = v.archetype != "sandbox"

      dns_servers = v.archetype == "sandbox" ? [] : compact([try(local.platform.dns_server_ip_addresses[v.region_key], null)])
      firewall_ip = try(local.platform.firewall_private_ip_addresses[v.region_key], null)

      hub_vnet_id = try(local.platform.hub_virtual_network_resource_ids[v.region_key], null)
      vhub_id     = try(local.platform.virtual_hub_resource_ids[v.region_key], null)

      github_org  = v.github_repository == null ? null : split("/", v.github_repository)[0]
      github_repo = v.github_repository == null ? null : split("/", v.github_repository)[1]

      tags = merge(var.tags, v.tags, {
        cost_center    = v.cost_center
        environment    = v.environment
        archetype      = v.archetype
        landing_zone   = k
        workload_owner = v.owner_group_object_id
        },
        # Read by the sandbox expiry automation (docs/03 section 5).
        v.expires_on == null ? {} : { expires_on = v.expires_on }
      )
    }
  }

  # Deterministic subnet layout inside each /24 spoke.
  subnet_layout = {
    for k, l in local.lz : k => {
      app               = cidrsubnet(l.spoke_cidr, 1, 0) # .0/25   application tier
      private_endpoints = cidrsubnet(l.spoke_cidr, 2, 2) # .128/26 Private Endpoints (default PaaS access path)
      integration       = cidrsubnet(l.spoke_cidr, 3, 6) # .192/27 delegated / VNet integration
    }
  }

  udr_enabled = {
    for k, l in local.lz : k => local.hub_and_spoke && l.connected && l.firewall_ip != null
  }
}

# Fail fast with actionable messages instead of opaque API errors.
check "workload_landing_zone_contract" {
  assert {
    condition = alltrue([
      for lz in values(local.lz) : contains(keys(local.platform.management_group_resource_ids), local.mg_id_by_role[lz.mg_role])
    ])
    error_message = "Every workload archetype must map to an existing management group created by Day 1 (corp, online, sandbox, decommissioned)."
  }

  assert {
    condition = alltrue([
      for lz in values(var.workload_landing_zones) : contains(keys(local.platform.ipam_plan), lz.region_key)
    ])
    error_message = "Every workload region_key must exist in the Day 1 IPAM plan."
  }

  assert {
    condition = alltrue([
      for lz in values(var.workload_landing_zones) : lz.existing_subscription_id != null || var.subscription_billing_scope != null
    ])
    error_message = "subscription_billing_scope is required to create new subscriptions (or set existing_subscription_id)."
  }
}

module "workload_landing_zone" {
  source   = "Azure/avm-ptn-alz-sub-vending/azure"
  version  = "0.3.4"
  for_each = var.workload_landing_zones

  location         = local.lz[each.key].location
  enable_telemetry = true

  #--- Subscription ----------------------------------------------------------
  subscription_alias_enabled = each.value.existing_subscription_id == null
  subscription_alias_name    = each.value.existing_subscription_id == null ? "sub-${each.key}" : null
  subscription_display_name  = each.value.display_name
  subscription_billing_scope = each.value.existing_subscription_id == null ? var.subscription_billing_scope : null
  subscription_workload      = each.value.environment == "prod" ? "Production" : "DevTest"
  subscription_id            = each.value.existing_subscription_id
  # The lifecycle tag goes on the subscription only: resources inside a
  # decommissioned subscription are not updated (Enforce-ALZ-Decomm denies writes).
  subscription_tags = merge(local.lz[each.key].tags, each.value.decommissioned ? { lifecycle_state = "decommissioned" } : {})

  subscription_management_group_association_enabled = true
  subscription_management_group_id                  = local.mg_id_by_role[local.lz[each.key].mg_role]

  subscription_register_resource_providers_enabled = true

  #--- Resource groups -------------------------------------------------------
  resource_group_creation_enabled = true
  resource_groups = {
    network = {
      name         = "rg-network-${each.key}"
      location     = local.lz[each.key].location
      tags         = local.lz[each.key].tags
      lock_enabled = true # workload Contributors cannot delete the platform-managed network
      lock_name    = "lock-platform-network"
    }
    identity = {
      name     = "rg-identity-${each.key}"
      location = local.lz[each.key].location
      tags     = local.lz[each.key].tags
    }
    network_watcher = {
      name     = "NetworkWatcherRG" # pre-created so subscription cancellation is clean
      location = local.lz[each.key].location
    }
  }

  #--- Network security groups (ALZ "Deny-Subnet-Without-Nsg" compliant) ----
  network_security_group_enabled = true
  network_security_groups = {
    default = {
      name               = "nsg-${each.key}"
      location           = local.lz[each.key].location
      resource_group_key = "network"
      tags               = local.lz[each.key].tags
      security_rules     = {}
    }
  }

  #--- Route table: default route to Azure Firewall (hub-and-spoke only) -----
  route_table_enabled = local.udr_enabled[each.key]
  route_tables = local.udr_enabled[each.key] ? {
    default = {
      name                          = "rt-${each.key}"
      location                      = local.lz[each.key].location
      resource_group_key            = "network"
      bgp_route_propagation_enabled = false # on-premises routes must also traverse the firewall
      tags                          = local.lz[each.key].tags
      routes = {
        default = {
          name                   = "default-to-azure-firewall"
          address_prefix         = "0.0.0.0/0"
          next_hop_type          = "VirtualAppliance"
          next_hop_in_ip_address = local.lz[each.key].firewall_ip
        }
      }
    }
  } : {}

  #--- Spoke virtual network --------------------------------------------------
  virtual_network_enabled = true
  virtual_networks = {
    spoke = {
      name               = "vnet-${each.key}"
      location           = local.lz[each.key].location
      resource_group_key = "network"
      address_space      = [local.lz[each.key].spoke_cidr]
      dns_servers        = local.lz[each.key].dns_servers
      tags               = local.lz[each.key].tags

      subnets = {
        app = {
          name                            = "snet-app"
          address_prefix                  = local.subnet_layout[each.key].app
          default_outbound_access_enabled = false # private subnet (explicit egress only)
          network_security_group          = { key_reference = "default" }
          route_table                     = local.udr_enabled[each.key] ? { key_reference = "default" } : null
        }
        private_endpoints = {
          name                              = "snet-private-endpoints"
          address_prefix                    = local.subnet_layout[each.key].private_endpoints
          default_outbound_access_enabled   = false
          private_endpoint_network_policies = "Enabled" # NSG + UDR apply to Private Endpoints
          network_security_group            = { key_reference = "default" }
          route_table                       = local.udr_enabled[each.key] ? { key_reference = "default" } : null
        }
        integration = {
          name                            = "snet-integration"
          address_prefix                  = local.subnet_layout[each.key].integration
          default_outbound_access_enabled = false
          network_security_group          = { key_reference = "default" }
          route_table                     = local.udr_enabled[each.key] ? { key_reference = "default" } : null
        }
      }

      # Hub-and-spoke: peering to the regional hub
      hub_network_resource_id = local.hub_and_spoke && local.lz[each.key].connected ? local.lz[each.key].hub_vnet_id : null
      hub_peering_enabled     = local.hub_and_spoke && local.lz[each.key].connected
      hub_peering_options_tohub = {
        allow_forwarded_traffic = true
        use_remote_gateways     = var.hub_gateways_present
      }
      hub_peering_options_fromhub = {
        allow_forwarded_traffic = true
        allow_gateway_transit   = var.hub_gateways_present
      }

      # Virtual WAN: hub connection secured by routing intent
      vwan_connection_enabled = local.virtual_wan && local.lz[each.key].connected
      vwan_hub_resource_id    = local.virtual_wan && local.lz[each.key].connected ? local.lz[each.key].vhub_id : null
      vwan_security_configuration = {
        secure_internet_traffic = true
        secure_private_traffic  = true
        routing_intent_enabled  = true
      }
    }
  }

  #--- RBAC: workload team -----------------------------------------------------
  role_assignment_enabled = true
  role_assignments = {
    workload_team_contributor = {
      principal_id   = each.value.owner_group_object_id
      definition     = "Contributor"
      relative_scope = ""
      principal_type = "Group"
    }
  }

  #--- Optional OIDC identity for the workload team's own pipeline -------------
  umi_enabled = each.value.github_repository != null
  user_managed_identities = each.value.github_repository == null ? {} : {
    deploy = {
      name               = "id-${each.key}-deploy"
      resource_group_key = "identity"
      location           = local.lz[each.key].location
      tags               = local.lz[each.key].tags
      role_assignments = {
        subscription_contributor = {
          definition     = "Contributor"
          relative_scope = ""
        }
      }
      federated_credentials_github = {
        environment = {
          name         = "github-${local.lz[each.key].github_repo}-${each.value.environment}"
          organization = local.lz[each.key].github_org
          repository   = local.lz[each.key].github_repo
          entity       = "environment"
          value        = each.value.environment
        }
      }
    }
  }

  #--- FinOps guardrail --------------------------------------------------------
  budget_enabled = true
  budgets = {
    monthly = {
      name              = "budget-${each.key}-monthly"
      amount            = each.value.budget_amount
      time_grain        = "Monthly"
      time_period_start = var.budget_start_date
      time_period_end   = "2031-12-31T00:00:00Z"
      relative_scope    = ""
      notifications = {
        actual_80 = {
          enabled        = true
          operator       = "GreaterThan"
          threshold      = 80
          threshold_type = "Actual"
          contact_emails = each.value.budget_contact_emails
        }
        forecast_100 = {
          enabled        = true
          operator       = "GreaterThan"
          threshold      = 100
          threshold_type = "Forecasted"
          contact_emails = each.value.budget_contact_emails
        }
      }
    }
  }
}
