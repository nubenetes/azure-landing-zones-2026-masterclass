###############################################################################
# Day 2 - Workload vending & operations: provider configuration
#
# Same authentication model as Day 1 (see ../day-1-platform-landing-zone/
# providers.tf): ARM_* environment variables for GitHub Actions and Azure
# DevOps, var.tfc_azure_dynamic_credentials for HCP Terraform / TFE, Azure
# CLI for local break-glass runs. No credentials in code.
###############################################################################

locals {
  tfc_dynamic_credentials = var.tfc_azure_dynamic_credentials == null ? null : var.tfc_azure_dynamic_credentials.default
  tfc_use_oidc            = local.tfc_dynamic_credentials == null ? null : true
  tfc_client_id_file      = try(local.tfc_dynamic_credentials.client_id_file_path, null)
  tfc_oidc_token_file     = try(local.tfc_dynamic_credentials.oidc_token_file_path, null)
}

# Tenant-scope operations (subscription aliases) and the vending module run
# through azapi; the default context is the Management subscription.
provider "azapi" {
  subscription_id            = var.management_subscription_id
  skip_provider_registration = true

  use_oidc             = local.tfc_use_oidc
  client_id_file_path  = local.tfc_client_id_file
  oidc_token_file_path = local.tfc_oidc_token_file
}

provider "azurerm" {
  subscription_id                 = var.management_subscription_id
  resource_provider_registrations = "none"
  storage_use_azuread             = true

  use_oidc             = local.tfc_use_oidc
  client_id_file_path  = local.tfc_client_id_file
  oidc_token_file_path = local.tfc_oidc_token_file

  features {}
}

# Central Private DNS zones live in the Connectivity subscription.
provider "azurerm" {
  alias                           = "connectivity"
  subscription_id                 = var.connectivity_subscription_id
  resource_provider_registrations = "none"

  use_oidc             = local.tfc_use_oidc
  client_id_file_path  = local.tfc_client_id_file
  oidc_token_file_path = local.tfc_oidc_token_file

  features {}
}
