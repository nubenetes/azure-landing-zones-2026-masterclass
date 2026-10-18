###############################################################################
# Day 0 - Bootstrap: Terraform & provider requirements
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment. Validate in a sandbox tenant before any real use.
#
# This stack is executed ONCE, locally, by a privileged platform engineer.
# It creates the trust anchors every later stage depends on:
#   * Remote state storage (Entra ID-only auth, CMK via Key Vault)
#   * Entra ID App Registrations + Workload Identity Federation (OIDC)
#   * Least-privilege RBAC for the CI/CD "plan" and "apply" identities
#
# After the first apply, migrate this stack's own state into the storage
# account it created (see README.md, "Step 4 - Migrate bootstrap state").
###############################################################################

terraform {
  required_version = ">= 1.12, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81" # AzureRM v5 is intentionally NOT used (ALZ AVM modules require v4).
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }

  # Uncomment AFTER the first successful apply and run:
  #   terraform init -migrate-state -backend-config=backend.hcl
  # backend "azurerm" {}
}

provider "azurerm" {
  subscription_id                 = var.bootstrap_subscription_id
  storage_use_azuread             = true # Shared Key is disabled on the state account.
  resource_provider_registrations = "core"

  features {
    key_vault {
      # Never silently purge a vault that protects state encryption keys.
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

provider "azuread" {
  tenant_id = var.tenant_id
}
