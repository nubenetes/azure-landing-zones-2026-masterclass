###############################################################################
# Day 1 - Platform Landing Zone: provider configuration
#
# Multi-provider architecture:
#   alz      -> resolves the ALZ Library (archetypes, policy & role assets)
#               into a deterministic model consumed by avm-ptn-alz.
#   azapi    -> ARM REST API (day-zero API versions, plan-time schema
#               validation, built-in retry). Used by every AVM pattern module.
#   azurerm  -> classic ARM resource lifecycle.
#
# ONE configuration, FOUR authentication contexts - no credentials in code:
#
#   Context                    | How the providers authenticate
#   ---------------------------+-----------------------------------------------
#   GitHub Actions             | ARM_USE_OIDC + ARM_CLIENT_ID (+ GitHub token)
#   Azure DevOps Pipelines     | ARM_USE_OIDC + ARM_ADO_PIPELINE_SERVICE_CONNECTION_ID
#                              | + SYSTEM_ACCESSTOKEN / SYSTEM_OIDCREQUESTURI
#   HCP Terraform / TFE        | var.tfc_azure_dynamic_credentials (token and
#                              | client-ID files written per run phase)
#   Local CLI (break-glass)    | Azure CLI login
#
# The attributes below are null unless HCP Terraform / Terraform Enterprise
# injects var.tfc_azure_dynamic_credentials, so the ARM_* environment
# variables (or the Azure CLI) remain in charge everywhere else.
###############################################################################

locals {
  # HCP Terraform / TFE dynamic provider credentials ("multiple configurations"
  # mode, required because several provider types and aliases are in use).
  tfc_dynamic_credentials = var.tfc_azure_dynamic_credentials == null ? null : var.tfc_azure_dynamic_credentials.default
  tfc_use_oidc            = local.tfc_dynamic_credentials == null ? null : true
  tfc_client_id_file      = try(local.tfc_dynamic_credentials.client_id_file_path, null)
  tfc_oidc_token_file     = try(local.tfc_dynamic_credentials.oidc_token_file_path, null)
}

provider "alz" {
  # The custom library lives next to the module that consumes it and depends
  # on the Microsoft-published ALZ Library (see lib/alz_library_metadata.json).
  library_overwrite_enabled = true
  library_references = [
    {
      custom_url = "${path.root}/../modules/platform-landing-zone/lib"
    }
  ]

  use_oidc             = local.tfc_use_oidc
  client_id_file_path  = local.tfc_client_id_file
  oidc_token_file_path = local.tfc_oidc_token_file
}

# Default azapi/azurerm context: Management subscription.
provider "azapi" {
  subscription_id            = var.platform_subscription_ids.management
  skip_provider_registration = true

  use_oidc             = local.tfc_use_oidc
  client_id_file_path  = local.tfc_client_id_file
  oidc_token_file_path = local.tfc_oidc_token_file
}

provider "azurerm" {
  subscription_id                 = var.platform_subscription_ids.management
  resource_provider_registrations = "none"
  storage_use_azuread             = true

  use_oidc             = local.tfc_use_oidc
  client_id_file_path  = local.tfc_client_id_file
  oidc_token_file_path = local.tfc_oidc_token_file

  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

# Connectivity subscription context (hub networking, DNS, firewall, DDoS).
provider "azapi" {
  alias                      = "connectivity"
  subscription_id            = var.platform_subscription_ids.connectivity
  skip_provider_registration = true

  use_oidc             = local.tfc_use_oidc
  client_id_file_path  = local.tfc_client_id_file
  oidc_token_file_path = local.tfc_oidc_token_file
}

provider "azurerm" {
  alias                           = "connectivity"
  subscription_id                 = var.platform_subscription_ids.connectivity
  resource_provider_registrations = "none"

  use_oidc             = local.tfc_use_oidc
  client_id_file_path  = local.tfc_client_id_file
  oidc_token_file_path = local.tfc_oidc_token_file

  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
