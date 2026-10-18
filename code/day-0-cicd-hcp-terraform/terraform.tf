###############################################################################
# Day 0 (optional) - HCP Terraform / Terraform Enterprise delivery
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment. Validate in a sandbox organisation/tenant first.
#
# Run AFTER code/day-0-bootstrap-oidc with `hcp_terraform` set there (the
# federated credentials for workspaces and Stacks are created in Day 0).
# Authentication: TFE_TOKEN (a short-lived team or user token) in the
# environment - never in code. Works for HCP Terraform (app.terraform.io) and
# Terraform Enterprise (set var.hostname).
###############################################################################

terraform {
  required_version = ">= 1.12, < 2.0"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.82"
    }
  }

  # Keep this stage's state in HCP Terraform itself (or in Azure Storage
  # alongside the other bootstrap state - see code/backend.hcl.example).
}

provider "tfe" {
  hostname     = var.hostname
  organization = var.organization
}
