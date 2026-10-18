###############################################################################
# Module: platform-landing-zone
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment. Validate in a sandbox tenant before any real use.
#
# Reusable, provider-agnostic composition of the ALZ platform landing zone.
# It contains NO provider configuration and NO backend, so the same code is
# consumed by:
#   * code/day-1-platform-landing-zone  (GitHub Actions, Azure DevOps,
#     HCP Terraform / Terraform Enterprise workspaces, local CLI)
#   * code/hcp-terraform/stacks/alz      (Terraform Stacks component)
#
# modtm / random / time are declared because the nested Azure Verified
# Modules use them; Terraform Stacks require every provider in the module
# tree to be passed explicitly (root modules inherit default instances).
#
# Required provider configurations (passed by the caller):
#   alz                  ALZ Library processor (library_references -> ./lib)
#   azapi, azurerm       Management subscription context
#   azapi.connectivity,  Connectivity subscription context
#   azurerm.connectivity
###############################################################################

terraform {
  required_version = "~> 1.12"

  required_providers {
    alz = {
      source  = "Azure/alz"
      version = "~> 0.21"
    }
    azapi = {
      source                = "Azure/azapi"
      version               = "~> 2.12"
      configuration_aliases = [azapi.connectivity]
    }
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 4.35"
      configuration_aliases = [azurerm.connectivity]
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
}
