###############################################################################
# Module: platform-landing-zone - derived values
#
# IMPORTANT (ALZ pattern module constraint): values passed into avm-ptn-alz
# must be KNOWN AT PLAN TIME. Resource IDs are therefore composed from inputs
# (string interpolation / azapi provider functions), never taken from module
# outputs. Ordering is enforced with the *_dependencies inputs instead.
###############################################################################

locals {
  #----------------------------------------------------------------------------
  # Regions
  #----------------------------------------------------------------------------
  primary_region_key = one([for k, r in var.regions : k if r.is_primary])
  primary_location   = var.regions[local.primary_region_key].location

  #----------------------------------------------------------------------------
  # Management group IDs by role. The prefix lets a second, isolated hierarchy
  # (e.g. the "canary" Terraform Stacks deployment) live in the same tenant:
  # MG IDs are tenant-unique, so the canary architecture definition uses the
  # same tree with "canary-" IDs (lib/architecture_definitions/*canary*).
  #----------------------------------------------------------------------------
  management_group_ids = {
    for role in ["alz", "platform", "identity", "management", "connectivity", "security", "landingzones", "corp", "online", "sandbox", "decommissioned"] :
    role => "${var.management_group_id_prefix}${role}"
  }

  hub_and_spoke_enabled = var.connectivity_type == "hub_and_spoke_vnet"
  virtual_wan_enabled   = var.connectivity_type == "virtual_wan"

  #----------------------------------------------------------------------------
  # IP Address Management (IPAM)
  #
  #   organization_supernet  /8   10.0.0.0/8
  #   └─ region (index n)    /12  cidrsubnet(/8, 4, n)        e.g. 10.0.0.0/12
  #      ├─ [0]  hub block   /16  connectivity (hub VNet or vWAN hub + sidecar)
  #      ├─ [1]  identity    /16
  #      ├─ [2]  corp-prod   /16  ┐
  #      ├─ [3]  corp-nonprod/16  │ consumed by Day 2 subscription vending:
  #      ├─ [4]  online-prod /16  │ each workload spoke receives a /24 slice
  #      ├─ [5]  online-nonp /16  ┘
  #      ├─ [6..14] reserved for growth (AI/data platforms, new archetypes)
  #      └─ [15] sandbox     /16  never peered, kept unique to allow promotion
  #----------------------------------------------------------------------------
  landing_zone_block_index = {
    hub            = 0
    identity       = 1
    corp-prod      = 2
    corp-nonprod   = 3
    online-prod    = 4
    online-nonprod = 5
    sandbox        = 15
  }

  region_supernets = { for k, r in var.regions : k => cidrsubnet(var.organization_supernet, 4, r.index) }

  ipam_plan = {
    for k, supernet in local.region_supernets : k => {
      location        = var.regions[k].location
      region_supernet = supernet
      blocks          = { for name, idx in local.landing_zone_block_index : name => cidrsubnet(supernet, 4, idx) }
    }
  }

  # Customer-managed hub VNet layout (/22 inside the hub /16)
  hub_vnet_layout = {
    for k, plan in local.ipam_plan : k => {
      vnet                 = cidrsubnet(plan.blocks.hub, 6, 0)                    # x.x.0.0/22
      firewall             = cidrsubnet(cidrsubnet(plan.blocks.hub, 6, 0), 4, 0)  # .0/26
      bastion              = cidrsubnet(cidrsubnet(plan.blocks.hub, 6, 0), 4, 1)  # .64/26
      gateway              = cidrsubnet(cidrsubnet(plan.blocks.hub, 6, 0), 5, 4)  # .128/27
      dns_resolver_inbound = cidrsubnet(cidrsubnet(plan.blocks.hub, 6, 0), 6, 10) # .160/28
      firewall_management  = cidrsubnet(cidrsubnet(plan.blocks.hub, 6, 0), 4, 3)  # .192/26
    }
  }

  # Microsoft-managed vWAN hub layout (/23 hub + /24 sidecar VNet)
  vwan_layout = {
    for k, plan in local.ipam_plan : k => {
      hub                  = cidrsubnet(plan.blocks.hub, 7, 0)                   # x.x.0.0/23
      sidecar_vnet         = cidrsubnet(plan.blocks.hub, 8, 2)                   # x.x.2.0/24
      dns_resolver_inbound = cidrsubnet(cidrsubnet(plan.blocks.hub, 8, 2), 4, 0) # .2.0/28
      bastion              = cidrsubnet(cidrsubnet(plan.blocks.hub, 8, 2), 2, 1) # .2.64/26
    }
  }

  #----------------------------------------------------------------------------
  # Naming (CAF abbreviations: rg, law, uami, dcr, vnet, fw, afwp, pdr, bas)
  #----------------------------------------------------------------------------
  management_rg_name = "rg-management-${local.primary_location}"
  law_name           = "law-management-${local.primary_location}"
  ama_uami_name      = "uami-management-ama-${local.primary_location}"
  dcr_names = {
    change_tracking = "dcr-change-tracking"
    vm_insights     = "dcr-vm-insights"
    defender_sql    = "dcr-defender-sql"
  }

  dns_rg_name  = "rg-hub-dns-${local.primary_location}"
  ddos_rg_name = "rg-hub-ddos-${local.primary_location}"
  ddos_name    = "ddos-${local.primary_location}"
  hub_rg_names = { for k, r in var.regions : k => "rg-hub-${r.location}" }

  #----------------------------------------------------------------------------
  # Plan-time-known resource IDs (azapi provider-defined functions)
  #----------------------------------------------------------------------------
  log_analytics_workspace_id = provider::azapi::resource_group_resource_id(
    var.platform_subscription_ids.management, local.management_rg_name, "Microsoft.OperationalInsights/workspaces", [local.law_name]
  )
  ama_uami_id = provider::azapi::resource_group_resource_id(
    var.platform_subscription_ids.management, local.management_rg_name, "Microsoft.ManagedIdentity/userAssignedIdentities", [local.ama_uami_name]
  )
  dcr_ids = {
    for k, name in local.dcr_names : k => provider::azapi::resource_group_resource_id(
      var.platform_subscription_ids.management, local.management_rg_name, "Microsoft.Insights/dataCollectionRules", [name]
    )
  }
  ddos_protection_plan_id = provider::azapi::resource_group_resource_id(
    var.platform_subscription_ids.connectivity, local.ddos_rg_name, "Microsoft.Network/ddosProtectionPlans", [local.ddos_name]
  )
  dns_rg_id = "/subscriptions/${var.platform_subscription_ids.connectivity}/resourceGroups/${local.dns_rg_name}"
  hub_rg_ids = {
    for k, name in local.hub_rg_names : k => "/subscriptions/${var.platform_subscription_ids.connectivity}/resourceGroups/${name}"
  }

  #----------------------------------------------------------------------------
  # Connectivity resource groups (created explicitly so that every module
  # receives a plan-time-known parent_id)
  #----------------------------------------------------------------------------
  connectivity_resource_groups = merge(
    { for k, r in var.regions : "hub-${k}" => { name = local.hub_rg_names[k], location = r.location } },
    var.connectivity_features.private_dns_zones ? { dns = { name = local.dns_rg_name, location = local.primary_location } } : {},
    var.connectivity_features.ddos_protection_plan ? { ddos = { name = local.ddos_rg_name, location = local.primary_location } } : {},
  )

  #----------------------------------------------------------------------------
  # ALZ policy default values (one value fans out to many assignments).
  # NOTE: the ALZ module expects jsonencode({ value = ... }).
  #----------------------------------------------------------------------------
  policy_default_values = merge(
    {
      log_analytics_workspace_id                  = jsonencode({ value = local.log_analytics_workspace_id })
      ama_user_assigned_managed_identity_id       = jsonencode({ value = local.ama_uami_id })
      ama_user_assigned_managed_identity_name     = jsonencode({ value = local.ama_uami_name })
      ama_change_tracking_data_collection_rule_id = jsonencode({ value = local.dcr_ids.change_tracking })
      ama_vm_insights_data_collection_rule_id     = jsonencode({ value = local.dcr_ids.vm_insights })
      ama_mdfc_sql_data_collection_rule_id        = jsonencode({ value = local.dcr_ids.defender_sql })
      private_dns_zone_subscription_id            = jsonencode({ value = var.platform_subscription_ids.connectivity })
      private_dns_zone_resource_group_name        = jsonencode({ value = local.dns_rg_name })
      private_dns_zone_region                     = jsonencode({ value = local.primary_location })
      resource_group_location                     = jsonencode({ value = local.primary_location })
      resource_group_name_service_health_alerts   = jsonencode({ value = "rg-service-health-alerts-${local.primary_location}" })
      resource_group_name_mdfc                    = jsonencode({ value = "rg-asc-export-${local.primary_location}" })
      email_security_contact                      = jsonencode({ value = var.security_contact_email })
      # Defined by the custom library (lib/alz_policy_default_values.json)
      allowed_locations = jsonencode({ value = length(var.allowed_locations) > 0 ? var.allowed_locations : [local.primary_location] })
    },
    var.connectivity_features.ddos_protection_plan ? {
      ddos_protection_plan_id = jsonencode({ value = local.ddos_protection_plan_id })
    } : {}
  )

  #----------------------------------------------------------------------------
  # Policy-as-Code: rollout phases (Audit -> Remediate -> Enforce)
  #
  # The phase toggles enforcement_mode on a curated set of assignments.
  # DoNotEnforce keeps compliance evaluation running (an "audit" signal) but
  # Deny does not block and DINE/Modify do not act on create/update.
  #----------------------------------------------------------------------------
  phased_deny_assignments = {
    landingzones = ["Deny-IP-forwarding", "Deny-MgmtPorts-Internet", "Deny-Subnet-Without-Nsg", "Deny-Storage-http", "Deny-Priv-Esc-AKS", "Deny-Privileged-AKS"]
    corp         = ["Deny-Public-Endpoints", "Deny-Public-IP-On-NIC", "Deny-HybridNetworking"]
    identity     = ["Deny-MgmtPorts-Internet", "Deny-Public-IP", "Deny-Subnet-Without-Nsg"]
  }
  phased_dine_assignments = {
    landingzones = ["Deploy-VM-Backup", "Deploy-SQL-TDE", "Deploy-SQL-Threat", "Deploy-AzSqlDb-Auditing"]
    corp         = ["Deploy-Private-DNS-Zones"]
  }

  deny_enforcement_mode = var.policy_enforcement_phase == "enforce" ? "Default" : "DoNotEnforce"
  dine_enforcement_mode = var.policy_enforcement_phase == "audit" ? "DoNotEnforce" : "Default"

  # Every modification is normalised to the same object shape so that the
  # list below has a single, well-defined element type.
  phase_modification_list = concat(
    flatten([
      for mg, names in local.phased_deny_assignments : [
        for name in names : {
          mg               = mg
          name             = name
          enforcement_mode = local.deny_enforcement_mode
          parameters       = null
          creation_enabled = null
        }
      ]
    ]),
    flatten([
      for mg, names in local.phased_dine_assignments : [
        for name in names : {
          mg               = mg
          name             = name
          enforcement_mode = local.dine_enforcement_mode
          parameters       = null
          creation_enabled = null
        }
      ]
    ]),
  )

  #----------------------------------------------------------------------------
  # Explicit, reviewed overrides (HCL) - parameters, enforcement, creation
  #----------------------------------------------------------------------------
  defender_plan_parameters = {
    for p in [
      "enableAscForServers", "enableAscForServersVulnerabilityAssessments", "enableAscForSql",
      "enableAscForAppServices", "enableAscForStorage", "enableAscForContainers", "enableAscForKeyVault",
      "enableAscForSqlOnVm", "enableAscForArm", "enableAscForOssDb", "enableAscForCosmosDbs", "enableAscForCspm",
    ] : p => jsonencode({ value = "DeployIfNotExists" })
  }

  static_modification_list = concat(
    [
      # Defender for Cloud: turn every plan of the ALZ MDFC initiative to DeployIfNotExists.
      {
        mg               = "alz"
        name             = "Deploy-MDFC-Config-H224"
        enforcement_mode = null
        parameters       = local.defender_plan_parameters
        creation_enabled = null
      },
      # Data-residency assignments (custom library) only exist when an allow-list is supplied.
      {
        mg               = "alz"
        name             = "Enforce-Allowed-Locations"
        enforcement_mode = null
        parameters       = null
        creation_enabled = length(var.allowed_locations) > 0
      },
      {
        mg               = "alz"
        name             = "Enforce-Allowed-Loc-RG"
        enforcement_mode = null
        parameters       = null
        creation_enabled = length(var.allowed_locations) > 0
      },
    ],
    # Without a DDoS plan, the Modify policy would reference a non-existent plan.
    var.connectivity_features.ddos_protection_plan ? [] : [
      for mg in ["connectivity", "landingzones"] : {
        mg               = mg
        name             = "Enable-DDoS-VNET"
        enforcement_mode = "DoNotEnforce"
        parameters       = null
        creation_enabled = null
      }
    ],
  )

  all_modifications = concat(local.phase_modification_list, local.static_modification_list)

  # Final shape expected by avm-ptn-alz: { <mg_id> = { policy_assignments = { <name> = {...} } } }
  policy_assignments_to_modify = {
    for mg in distinct([for m in local.all_modifications : m.mg]) : local.management_group_ids[mg] => {
      policy_assignments = {
        for m in local.all_modifications : m.name => {
          enforcement_mode = m.enforcement_mode
          parameters       = m.parameters
          creation_enabled = m.creation_enabled
        } if m.mg == mg
      }
    }
  }

  #----------------------------------------------------------------------------
  # Subscription placement (platform subscriptions -> platform MGs)
  #----------------------------------------------------------------------------
  subscription_placement = merge(
    {
      management   = { subscription_id = var.platform_subscription_ids.management, management_group_name = local.management_group_ids.management }
      connectivity = { subscription_id = var.platform_subscription_ids.connectivity, management_group_name = local.management_group_ids.connectivity }
      identity     = { subscription_id = var.platform_subscription_ids.identity, management_group_name = local.management_group_ids.identity }
    },
    var.platform_subscription_ids.security == null ? {} : {
      security = { subscription_id = var.platform_subscription_ids.security, management_group_name = local.management_group_ids.security }
    }
  )

  # Standing access for the platform team is Contributor-level only. Owner /
  # User Access Administrator must be activated just-in-time through Entra ID
  # PIM - and the Day 0 RBAC condition on the apply identity prevents this
  # pipeline from ever granting Owner, RBAC Administrator or UAA.
  management_group_role_assignments = var.platform_operators_group_object_id == null ? {} : {
    platform_operators = {
      management_group_name      = local.management_group_ids.platform
      role_definition_id_or_name = "Contributor"
      principal_id               = var.platform_operators_group_object_id
      principal_type             = "Group"
      description                = "Platform team operations group (standing Contributor; privileged roles via PIM)."
    }
  }
}
