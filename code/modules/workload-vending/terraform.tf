###############################################################################
# Module: workload-vending
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment. Validate in a sandbox tenant before any real use.
#
# Subscription vending + workload guardrails. No provider configuration and
# no backend: the platform contract arrives through var.platform (from Day 1
# remote state, HCP Terraform remote state, or a Stacks component output).
#
# modtm / random / time are declared because the nested Azure Verified
# Modules use them; Terraform Stacks require every provider in the module
# tree to be passed explicitly (root modules inherit default instances).
#
# Required provider configurations (passed by the caller):
#   azapi, azurerm         Management subscription context (tenant-scope ops)
#   azurerm.connectivity   Central Private DNS zones (Connectivity subscription)
###############################################################################

terraform {
  required_version = "~> 1.12"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
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
