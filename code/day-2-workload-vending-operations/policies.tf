###############################################################################
# Day 2 - Continuous governance: workload guardrails initiative
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment. Validate in a sandbox tenant before any real use.
#
# Policy-as-Code lifecycle driven by var.policy_enforcement_phase:
#
#   phase      | DINE policies        | Deny policy | Remediation tasks
#   -----------+----------------------+-------------+------------------
#   audit      | AuditIfNotExists     | Audit       | no
#   remediate  | DeployIfNotExists    | Audit       | yes (existing non-compliant)
#   enforce    | DeployIfNotExists    | Deny        | yes
#
# Definitions are authored as JSON (policies/*.json) so they can be linted,
# unit-tested and reviewed independently of Terraform.
###############################################################################

locals {
  mg_ids = local.platform.management_group_resource_ids

  policy_files = {
    diag_keyvault          = "${path.module}/policies/deploy-diagnostics-keyvault-log-analytics.json"
    defender_storage       = "${path.module}/policies/deploy-defender-storage-plan.json"
    deny_service_endpoints = "${path.module}/policies/deny-subnet-service-endpoints.json"
  }
  policy_documents = { for k, f in local.policy_files : k => jsondecode(file(f)) }

  dine_effect = var.policy_enforcement_phase == "audit" ? "AuditIfNotExists" : "DeployIfNotExists"
  deny_effect = var.policy_enforcement_phase == "enforce" ? "Deny" : "Audit"
  remediate   = var.policy_enforcement_phase != "audit"

  # Policy references inside the initiative that support remediation.
  dine_reference_ids = ["diag_keyvault", "defender_storage"]

  # Roles the assignment's managed identity needs for DeployIfNotExists.
  policy_identity_roles = {
    monitoring_contributor    = "Monitoring Contributor"    # write diagnostic settings
    log_analytics_contributor = "Log Analytics Contributor" # link to the workspace
    security_admin            = "Security Admin"            # set Defender pricings
  }
}

#------------------------------------------------------------------------------
# Definitions at the intermediate root (reusable by every child MG)
#------------------------------------------------------------------------------
resource "azurerm_policy_definition" "custom" {
  for_each = local.policy_documents

  name                = each.value.name
  policy_type         = "Custom"
  mode                = each.value.properties.mode
  display_name        = each.value.properties.displayName
  description         = each.value.properties.description
  management_group_id = local.mg_ids["alz"]
  metadata            = jsonencode(each.value.properties.metadata)
  parameters          = jsonencode(each.value.properties.parameters)
  policy_rule         = jsonencode(each.value.properties.policyRule)
}

#------------------------------------------------------------------------------
# Initiative: Workload Landing Zone guardrails (2026)
#------------------------------------------------------------------------------
resource "azurerm_management_group_policy_set_definition" "workload_guardrails" {
  name                = "Workload-LZ-Guardrails-2026"
  policy_type         = "Custom"
  display_name        = "Workload Landing Zone guardrails (2026 masterclass)"
  description         = "Diagnostics to Log Analytics, Defender for Storage V2 and the Private-Endpoints-by-default network rule. Generated with Claude Opus 5.5 - untested reference."
  management_group_id = local.mg_ids["alz"]

  metadata = jsonencode({
    version  = "1.0.0"
    category = "Landing Zone"
    source   = "nubenetes/azure-landing-zones-2026-masterclass"
  })

  parameters = jsonencode({
    dineEffect = {
      type          = "String"
      allowedValues = ["DeployIfNotExists", "AuditIfNotExists", "Disabled"]
      defaultValue  = "AuditIfNotExists"
      metadata      = { displayName = "Effect for DeployIfNotExists policies" }
    }
    denyEffect = {
      type          = "String"
      allowedValues = ["Deny", "Audit", "Disabled"]
      defaultValue  = "Audit"
      metadata      = { displayName = "Effect for Deny policies" }
    }
    logAnalytics = {
      type     = "String"
      metadata = { displayName = "Central Log Analytics workspace", strongType = "omsWorkspace", assignPermissions = true }
    }
    malwareScanningCapGBPerMonth = {
      type         = "Integer"
      defaultValue = 5000
      metadata     = { displayName = "Defender for Storage malware scanning cap (GB/month/account)" }
    }
    deploymentLocation = {
      type     = "String"
      metadata = { displayName = "Location for subscription-scope deployments", strongType = "location" }
    }
    allowedServiceEndpoints = {
      type         = "Array"
      defaultValue = []
      metadata     = { displayName = "Approved service endpoints (documented exceptions)" }
    }
  })

  policy_definition_reference {
    reference_id         = "diag_keyvault"
    policy_definition_id = azurerm_policy_definition.custom["diag_keyvault"].id
    parameter_values = jsonencode({
      effect       = { value = "[parameters('dineEffect')]" }
      logAnalytics = { value = "[parameters('logAnalytics')]" }
    })
  }

  policy_definition_reference {
    reference_id         = "defender_storage"
    policy_definition_id = azurerm_policy_definition.custom["defender_storage"].id
    parameter_values = jsonencode({
      effect                       = { value = "[parameters('dineEffect')]" }
      malwareScanningCapGBPerMonth = { value = "[parameters('malwareScanningCapGBPerMonth')]" }
      deploymentLocation           = { value = "[parameters('deploymentLocation')]" }
    })
  }

  policy_definition_reference {
    reference_id         = "deny_service_endpoints"
    policy_definition_id = azurerm_policy_definition.custom["deny_service_endpoints"].id
    parameter_values = jsonencode({
      effect                  = { value = "[parameters('denyEffect')]" }
      allowedServiceEndpoints = { value = "[parameters('allowedServiceEndpoints')]" }
    })
  }
}

#------------------------------------------------------------------------------
# Assignment at the Workload Landing Zones management group
#------------------------------------------------------------------------------
resource "azurerm_management_group_policy_assignment" "workload_guardrails" {
  name                 = "Wlz-Guardrails-2026" # <= 24 characters
  display_name         = "Workload Landing Zone guardrails (2026)"
  description          = "Phase: ${var.policy_enforcement_phase}. Managed by Day 2 IaC."
  management_group_id  = local.mg_ids["landingzones"]
  policy_definition_id = azurerm_management_group_policy_set_definition.workload_guardrails.id
  location             = local.platform.primary_location
  enforce              = true # the phase is expressed through effects, not enforcement mode

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    dineEffect                   = { value = local.dine_effect }
    denyEffect                   = { value = local.deny_effect }
    logAnalytics                 = { value = local.platform.log_analytics_workspace_id }
    malwareScanningCapGBPerMonth = { value = var.defender_storage_malware_cap_gb }
    deploymentLocation           = { value = local.platform.primary_location }
    allowedServiceEndpoints      = { value = var.allowed_service_endpoints }
  })

  non_compliance_message {
    content = "Workload Landing Zone guardrail (${var.policy_enforcement_phase} phase). See docs/06-waf-simplicity-vs-security.md for the remediation runbook."
  }
}

# The assignment identity needs rights at the assignment scope ...
resource "azurerm_role_assignment" "guardrails_identity_mg" {
  for_each = local.policy_identity_roles

  scope                = local.mg_ids["landingzones"]
  role_definition_name = each.value
  principal_id         = azurerm_management_group_policy_assignment.workload_guardrails.identity[0].principal_id
  principal_type       = "ServicePrincipal"
  description          = "Workload guardrails DINE identity (${each.key})."
}

# ... and on the central workspace, which lives OUTSIDE that scope
# (Management subscription under the Platform MG).
resource "azurerm_role_assignment" "guardrails_identity_workspace" {
  scope                = local.platform.log_analytics_workspace_id
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_management_group_policy_assignment.workload_guardrails.identity[0].principal_id
  principal_type       = "ServicePrincipal"
  description          = "Workload guardrails DINE identity - central workspace."
}

#------------------------------------------------------------------------------
# Remediation for pre-existing, non-compliant resources
#------------------------------------------------------------------------------
resource "azurerm_management_group_policy_remediation" "workload_guardrails" {
  for_each = local.remediate ? toset(local.dine_reference_ids) : toset([])

  name                           = "remediate-${replace(each.value, "_", "-")}"
  management_group_id            = local.mg_ids["landingzones"]
  policy_assignment_id           = azurerm_management_group_policy_assignment.workload_guardrails.id
  policy_definition_reference_id = each.value
  failure_percentage             = 0.1 # stop if more than 10% of deployments fail
  parallel_deployments           = 10

  depends_on = [
    azurerm_role_assignment.guardrails_identity_mg,
    azurerm_role_assignment.guardrails_identity_workspace,
  ]
}
