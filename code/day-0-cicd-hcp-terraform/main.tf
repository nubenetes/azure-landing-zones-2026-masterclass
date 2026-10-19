###############################################################################
# Day 0 (optional) - HCP Terraform / Terraform Enterprise delivery
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment. Validate in a sandbox organisation/tenant first.
#
#   delivery_model = "workspaces"
#     alz-platform  (code/day-1-platform-landing-zone)
#        │ run trigger + remote state sharing
#        ▼
#     alz-workloads (code/day-2-workload-vending-operations)
#     Dynamic provider credentials: plan phase -> plan app, apply phase ->
#     apply app (TFC_AZURE_PLAN_CLIENT_ID / TFC_AZURE_APPLY_CLIENT_ID).
#
#   delivery_model = "stacks"
#     Stack "alz" (code/hcp-terraform-stacks/alz): components platform ->
#     workloads, deployments canary + production (identity_token blocks).
###############################################################################

data "tfe_organization" "this" {
  name = var.organization
}

locals {
  workspaces_enabled = contains(["workspaces", "both"], var.delivery_model)
  stacks_enabled     = contains(["stacks", "both"], var.delivery_model)

  workspaces = local.workspaces_enabled ? {
    platform = {
      name              = "alz-platform"
      description       = "ALZ Day 1 - platform landing zone (management groups, policy, management, connectivity). Generated reference - untested."
      working_directory = "code/day-1-platform-landing-zone"
      trigger_patterns  = ["code/day-1-platform-landing-zone/**/*", "code/modules/platform-landing-zone/**/*"]
    }
    workloads = {
      name              = "alz-workloads"
      description       = "ALZ Day 2 - subscription vending and workload guardrails. Generated reference - untested."
      working_directory = "code/day-2-workload-vending-operations"
      trigger_patterns  = ["code/day-2-workload-vending-operations/**/*", "code/modules/workload-vending/**/*"]
    }
  } : {}
}

resource "tfe_project" "alz" {
  organization = data.tfe_organization.this.name
  name         = var.project_name
  description  = "Azure Landing Zones 2026 masterclass (generated with Claude Opus 5.5 - untested reference)."
}

#------------------------------------------------------------------------------
# Dynamic provider credentials (no secrets): one variable set for the project
#------------------------------------------------------------------------------
resource "tfe_variable_set" "azure_oidc" {
  organization      = data.tfe_organization.this.name
  name              = "alz-azure-dynamic-credentials"
  description       = "Azure workload identity federation for the ALZ workspaces. Identifiers only - no secrets."
  parent_project_id = tfe_project.alz.id
}

resource "tfe_project_variable_set" "azure_oidc" {
  project_id      = tfe_project.alz.id
  variable_set_id = tfe_variable_set.azure_oidc.id
}

locals {
  oidc_env = {
    TFC_AZURE_PROVIDER_AUTH   = "true"
    TFC_AZURE_PLAN_CLIENT_ID  = var.plan_client_id  # plan phase  -> read-only identity
    TFC_AZURE_APPLY_CLIENT_ID = var.apply_client_id # apply phase -> privileged identity
    ARM_TENANT_ID             = var.tenant_id
    ARM_SUBSCRIPTION_ID       = var.management_subscription_id
  }
}

resource "tfe_variable" "azure_oidc" {
  for_each = local.oidc_env

  key             = each.key
  value           = each.value
  category        = "env"
  description     = "Managed by code/day-0-cicd-hcp-terraform."
  variable_set_id = tfe_variable_set.azure_oidc.id
}

#------------------------------------------------------------------------------
# Workspaces (same root modules as GitHub Actions / Azure DevOps)
#------------------------------------------------------------------------------
resource "tfe_workspace" "this" {
  for_each = local.workspaces

  name                = each.value.name
  description         = each.value.description
  project_id          = tfe_project.alz.id
  working_directory   = each.value.working_directory
  trigger_patterns    = each.value.trigger_patterns
  terraform_version   = var.terraform_version
  auto_apply          = false # every apply is a human confirmation of a reviewed plan
  speculative_enabled = true  # plans on pull requests
  queue_all_runs      = false
  tag_names           = ["alz", "platform-team", each.key]

  # Exactly one VCS authentication attribute may be present: the provider
  # rejects both, even when one of them would be null.
  dynamic "vcs_repo" {
    for_each = var.vcs.github_app_installation_id != null ? [var.vcs] : []
    content {
      identifier                 = vcs_repo.value.identifier
      branch                     = vcs_repo.value.branch
      github_app_installation_id = vcs_repo.value.github_app_installation_id
    }
  }

  dynamic "vcs_repo" {
    for_each = var.vcs.oauth_token_id != null ? [var.vcs] : []
    content {
      identifier     = vcs_repo.value.identifier
      branch         = vcs_repo.value.branch
      oauth_token_id = vcs_repo.value.oauth_token_id
    }
  }
}

resource "tfe_workspace_settings" "this" {
  for_each = local.workspaces

  workspace_id        = tfe_workspace.this[each.key].id
  agent_pool_id       = var.agent_pool_id
  execution_mode      = var.agent_pool_id == null ? "remote" : "agent"
  assessments_enabled = var.health_assessments_enabled # continuous drift detection

  # Only alz-workloads may read the platform contract.
  global_remote_state       = false
  remote_state_consumer_ids = each.key == "platform" ? [tfe_workspace.this["workloads"].id] : []
}

# Day 2 reads Day 1 outputs from the platform workspace (see the root module).
resource "tfe_variable" "hcp_platform_workspace" {
  count = local.workspaces_enabled ? 1 : 0

  key          = "hcp_platform_workspace"
  category     = "terraform"
  hcl          = true
  description  = "Day 1 state location for the workloads root module. Managed by code/day-0-cicd-hcp-terraform."
  workspace_id = tfe_workspace.this["workloads"].id
  value        = <<-EOT
    {
      hostname     = "${var.hostname}"
      organization = "${var.organization}"
      workspace    = "${local.workspaces.platform.name}"
    }
  EOT
}

# A successful platform apply queues a workloads plan (still needs approval).
resource "tfe_run_trigger" "platform_to_workloads" {
  count = local.workspaces_enabled ? 1 : 0

  workspace_id  = tfe_workspace.this["workloads"].id
  sourceable_id = tfe_workspace.this["platform"].id
}

#------------------------------------------------------------------------------
# Terraform Stack (HCP Terraform; Terraform Enterprise 2.0+)
#------------------------------------------------------------------------------
# The Stack's vcs_repo is a single nested block and the provider rejects
# github_app_installation_id and oauth_token_id together (even when one is
# unknown at plan time), so each VCS authentication mode gets its own resource.
resource "tfe_stack" "alz_github_app" {
  count = local.stacks_enabled && var.vcs.github_app_installation_id != null ? 1 : 0

  name                = "alz"
  description         = "ALZ platform + workloads as one Stack: canary and production deployments. Generated reference - untested."
  project_id          = tfe_project.alz.id
  agent_pool_id       = var.agent_pool_id
  working_directory   = "code/hcp-terraform-stacks/alz"
  speculative_enabled = true

  vcs_repo {
    identifier                 = var.vcs.identifier
    branch                     = var.vcs.branch
    github_app_installation_id = var.vcs.github_app_installation_id
  }
}

resource "tfe_stack" "alz_oauth" {
  count = local.stacks_enabled && var.vcs.oauth_token_id != null ? 1 : 0

  name                = "alz"
  description         = "ALZ platform + workloads as one Stack: canary and production deployments. Generated reference - untested."
  project_id          = tfe_project.alz.id
  agent_pool_id       = var.agent_pool_id
  working_directory   = "code/hcp-terraform-stacks/alz"
  speculative_enabled = true

  vcs_repo {
    identifier     = var.vcs.identifier
    branch         = var.vcs.branch
    oauth_token_id = var.vcs.oauth_token_id
  }
}
