###############################################################################
# Day 2 - Workload vending & operations (root): Terraform & providers
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

  # Partial configuration for GitHub Actions / Azure DevOps runs:
  #   terraform init \
  #     -backend-config=../backend.hcl \
  #     -backend-config="container_name=tfstate-workloads" \
  #     -backend-config="key=day-2-workload-vending-operations.tfstate"
  # HCP Terraform / Terraform Enterprise override it during remote runs.
  backend "azurerm" {}
}
