###############################################################################
# Day 1 - Platform Landing Zone (root): Terraform & provider requirements
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment. Validate in a sandbox tenant before any real use.
#
# Version constraints follow the Microsoft ALZ guidance for Terraform (2026):
#   * Terraform    ~> 1.12
#   * AzureRM      ~> 4.x   (v5 is NOT supported by the ALZ AVM modules)
#   * AzAPI        ~> 2.x   (mandatory - AVM pattern modules are azapi-first)
#   * ALZ provider ~> 0.21  (processes the ALZ Library into policy assets)
###############################################################################

terraform {
  required_version = "~> 1.12"

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
  }

  # Partial configuration - values are injected at `terraform init` time by
  # GitHub Actions / Azure DevOps. HCP Terraform and Terraform Enterprise
  # override this block with their own state backend during remote runs.
  #   terraform init \
  #     -backend-config=../backend.hcl \
  #     -backend-config="container_name=tfstate-platform" \
  #     -backend-config="key=day-1-platform-landing-zone.tfstate"
  backend "azurerm" {}
}
