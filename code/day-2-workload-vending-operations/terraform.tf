###############################################################################
# Day 2 - Workload vending & operations: Terraform & providers
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment. Validate in a sandbox tenant before any real use.
###############################################################################

terraform {
  required_version = "~> 1.12"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
  }

  #   terraform init \
  #     -backend-config=../backend.hcl \
  #     -backend-config="container_name=tfstate-workloads" \
  #     -backend-config="key=day-2-workload-vending-operations.tfstate"
  backend "azurerm" {}
}

# Tenant-scope operations (subscription aliases) and the vending module run
# through azapi; the default context is the Management subscription.
provider "azapi" {
  subscription_id            = var.management_subscription_id
  skip_provider_registration = true
}

provider "azurerm" {
  subscription_id                 = var.management_subscription_id
  resource_provider_registrations = "none"
  features {}
}

# Central Private DNS zones live in the Connectivity subscription.
provider "azurerm" {
  alias                           = "connectivity"
  subscription_id                 = var.connectivity_subscription_id
  resource_provider_registrations = "none"
  features {}
}
