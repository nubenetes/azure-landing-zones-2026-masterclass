# -----------------------------------------------------------------------------
# Terraform Stack "alz" - providers
#
# Every provider instance authenticates with the deployment's identity token
# (workload identity federation) - no ARM_* variables, no secrets.
# Stacks require every provider used anywhere in a component's module tree
# to be configured here and passed explicitly (random, time and modtm are
# used inside the Azure Verified Modules).
# -----------------------------------------------------------------------------

required_providers {
  alz = {
    source  = "Azure/alz"
    version = "~> 0.21"
  }
  azapi = {
    source  = "Azure/azapi"
    version = "~> 2.12"
  }
  azurerm = {
    source  = "hashicorp/azurerm"
    version = "~> 4.35"
  }
  modtm = {
    source  = "Azure/modtm"
    version = "~> 0.3"
  }
  random = {
    source  = "hashicorp/random"
    version = "~> 3.6"
  }
  time = {
    source  = "hashicorp/time"
    version = "~> 0.9"
  }
}

provider "alz" "this" {
  config {
    library_overwrite_enabled = true
    library_references = [
      {
        custom_url = var.alz_library_url
      }
    ]

    tenant_id  = var.tenant_id
    client_id  = var.client_id
    use_oidc   = true
    oidc_token = var.identity_token
  }
}

provider "azapi" "management" {
  config {
    subscription_id            = var.platform_subscription_ids.management
    tenant_id                  = var.tenant_id
    client_id                  = var.client_id
    use_oidc                   = true
    oidc_token                 = var.identity_token
    skip_provider_registration = true
  }
}

provider "azapi" "connectivity" {
  config {
    subscription_id            = var.platform_subscription_ids.connectivity
    tenant_id                  = var.tenant_id
    client_id                  = var.client_id
    use_oidc                   = true
    oidc_token                 = var.identity_token
    skip_provider_registration = true
  }
}

provider "azurerm" "management" {
  config {
    features {}
    subscription_id                 = var.platform_subscription_ids.management
    tenant_id                       = var.tenant_id
    client_id                       = var.client_id
    use_oidc                        = true
    oidc_token                      = var.identity_token
    resource_provider_registrations = "none"
    storage_use_azuread             = true
  }
}

provider "azurerm" "connectivity" {
  config {
    features {}
    subscription_id                 = var.platform_subscription_ids.connectivity
    tenant_id                       = var.tenant_id
    client_id                       = var.client_id
    use_oidc                        = true
    oidc_token                      = var.identity_token
    resource_provider_registrations = "none"
  }
}

provider "modtm" "this" {
  config {}
}

provider "random" "this" {
  config {}
}

provider "time" "this" {
  config {}
}
