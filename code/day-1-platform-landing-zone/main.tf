###############################################################################
# Day 1 - Platform Landing Zone: root module (entry point)
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment. Validate in a sandbox tenant before any real use.
#
# Thin wrapper: backend + provider configuration live here, all logic lives
# in ../modules/platform-landing-zone (shared with the Terraform Stacks
# configuration in ../hcp-terraform/stacks/alz).
#
# The SAME root module is executed by every delivery platform:
#   GitHub Actions ........ .github/workflows/terraform-*.yml   (OIDC env vars)
#   Azure DevOps .......... pipelines/azure-devops/*.yml        (WIF service connections)
#   HCP Terraform / TFE ... VCS-driven workspace                (dynamic provider credentials)
#   Local CLI ............. break-glass only                    (Azure CLI login)
###############################################################################

module "platform" {
  source = "../modules/platform-landing-zone"

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
  enable_telemetry                   = var.enable_telemetry
  tags                               = var.tags

  providers = {
    alz                  = alz
    azapi                = azapi
    azapi.connectivity   = azapi.connectivity
    azurerm              = azurerm
    azurerm.connectivity = azurerm.connectivity
  }
}
