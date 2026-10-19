###############################################################################
# Day 0 (optional) - Azure DevOps delivery: Terraform & providers
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment. Validate in a sandbox organisation/tenant first.
#
# Run AFTER code/day-0-bootstrap-oidc (it consumes the plan/apply app
# registrations). Authentication (no secrets in code):
#   azuredevops : AZDO_ORG_SERVICE_URL + Entra ID login (az login) or a short-lived PAT in AZDO_PERSONAL_ACCESS_TOKEN
#   azuread     : Azure CLI login of the same operator
###############################################################################

terraform {
  required_version = ">= 1.12, < 2.0"

  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~> 1.16"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
  }

  # Store this stage's state next to the bootstrap state:
  #   terraform init -backend-config=../backend.hcl \
  #     -backend-config="container_name=tfstate-bootstrap" \
  #     -backend-config="key=day-0-cicd-azure-devops.tfstate"
  backend "azurerm" {}
}

provider "azuredevops" {
  org_service_url = var.organization_url
}

provider "azuread" {
  tenant_id = var.tenant_id
}
