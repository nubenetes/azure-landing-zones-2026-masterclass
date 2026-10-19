###############################################################################
# Day 2 - Workload vending & operations: root module (entry point)
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment. Validate in a sandbox tenant before any real use.
#
# Reads the Day 1 platform contract from wherever the delivery platform keeps
# state, then calls ../modules/workload-vending (shared with the Terraform
# Stacks configuration in ../hcp-terraform/stacks/alz).
###############################################################################

# GitHub Actions / Azure DevOps: Day 1 state in Azure Storage (Entra ID auth).
data "terraform_remote_state" "platform_azurerm" {
  count   = var.hcp_platform_workspace == null ? 1 : 0
  backend = "azurerm"

  config = {
    resource_group_name  = var.platform_state.resource_group_name
    storage_account_name = var.platform_state.storage_account_name
    container_name       = var.platform_state.container_name
    key                  = var.platform_state.key
    use_azuread_auth     = true
    subscription_id      = var.management_subscription_id
  }
}

# HCP Terraform / Terraform Enterprise: Day 1 state in the platform workspace
# (requires remote state sharing from alz-platform to this workspace).
data "terraform_remote_state" "platform_hcp" {
  count   = var.hcp_platform_workspace == null ? 0 : 1
  backend = "remote"

  config = {
    hostname     = var.hcp_platform_workspace.hostname
    organization = var.hcp_platform_workspace.organization
    workspaces = {
      name = var.hcp_platform_workspace.workspace
    }
  }
}

check "platform_state_source" {
  assert {
    condition     = var.hcp_platform_workspace != null || var.platform_state != null
    error_message = "Set platform_state (Azure Storage) or hcp_platform_workspace (HCP Terraform / TFE)."
  }
}

locals {
  platform_outputs = one(concat(
    [for s in data.terraform_remote_state.platform_azurerm : s.outputs],
    [for s in data.terraform_remote_state.platform_hcp : s.outputs],
  ))
}

module "workloads" {
  source = "../modules/workload-vending"

  platform                        = local.platform_outputs
  subscription_billing_scope      = var.subscription_billing_scope
  workload_landing_zones          = var.workload_landing_zones
  budget_start_date               = var.budget_start_date
  hub_gateways_present            = var.hub_gateways_present
  policy_enforcement_phase        = var.policy_enforcement_phase
  allowed_service_endpoints       = var.allowed_service_endpoints
  defender_storage_malware_cap_gb = var.defender_storage_malware_cap_gb
  tags                            = var.tags

  providers = {
    azapi                = azapi
    azurerm              = azurerm
    azurerm.connectivity = azurerm.connectivity
  }
}
