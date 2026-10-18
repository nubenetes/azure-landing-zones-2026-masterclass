###############################################################################
# Day 1 - Platform Landing Zone: provider configuration
#
# Multi-provider architecture:
#   alz      -> resolves the ALZ Library (archetypes, policy & role assets)
#               into a deterministic model consumed by avm-ptn-alz.
#   azapi    -> ARM REST API (day-zero API versions, plan-time schema
#               validation, built-in retry). Used by every AVM pattern module.
#   azurerm  -> classic ARM resource lifecycle (resource groups, and inside
#               the management/connectivity modules where still used).
#
# Authentication: none of these blocks contain credentials. In CI the
# ARM_USE_OIDC / ARM_CLIENT_ID / ARM_TENANT_ID environment variables are set
# by the workflow and every provider performs Workload Identity Federation.
# Locally, the providers fall back to Azure CLI authentication.
###############################################################################

provider "alz" {
  # The local ./lib folder is a *custom library* that depends on the
  # Microsoft-published ALZ Library (see lib/alz_library_metadata.json).
  # Pinning the dependency ref there makes policy changes explicit and
  # reviewable in pull requests - never float to "latest".
  library_overwrite_enabled = true
  library_references = [
    {
      custom_url = "${path.root}/lib"
    }
  ]
}

# Default azapi/azurerm context: Management subscription.
provider "azapi" {
  subscription_id            = var.platform_subscription_ids.management
  skip_provider_registration = true
}

provider "azurerm" {
  subscription_id                 = var.platform_subscription_ids.management
  resource_provider_registrations = "none"
  storage_use_azuread             = true

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
}

provider "azurerm" {
  alias                           = "connectivity"
  subscription_id                 = var.platform_subscription_ids.connectivity
  resource_provider_registrations = "none"

  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
