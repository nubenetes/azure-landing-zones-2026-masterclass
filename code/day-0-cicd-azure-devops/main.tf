###############################################################################
# Day 0 (optional) - Azure DevOps delivery
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment. Validate in a sandbox organisation/tenant first.
#
# Creates the Azure DevOps side of the zero-secret model:
#   * two Workload Identity Federation service connections (plan / apply),
#     scoped to the root parent management group, backed by the Day 0 apps
#   * the federated credentials on those apps (issuer/subject come from the
#     service connections, so they are created here, not in Day 0)
#   * environment "alz-production" with approvals + exclusive lock
#   * branch control on the apply service connection (main only)
#   * the three YAML pipelines and least-privilege pipeline authorisations:
#       sc-alz-plan  -> PR validation, apply (plan stages), drift detection
#       sc-alz-apply -> apply pipeline ONLY
###############################################################################

data "azuredevops_project" "this" {
  name = var.project_name
}

data "azuread_application" "plan" {
  client_id = var.plan_client_id
}

data "azuread_application" "apply" {
  client_id = var.apply_client_id
}

locals {
  identities = {
    plan = {
      name        = var.service_connection_names.plan
      client_id   = var.plan_client_id
      application = data.azuread_application.plan.id
      description = "ALZ read-only plan identity (Workload Identity Federation). Managed by Terraform."
    }
    apply = {
      name        = var.service_connection_names.apply
      client_id   = var.apply_client_id
      application = data.azuread_application.apply.id
      description = "ALZ privileged apply identity (Workload Identity Federation). Gated by checks. Managed by Terraform."
    }
  }

  pipelines = {
    pr_validation = { name = "alz-pr-validation", yml = "pipelines/azure-devops/alz-pr-validation.yml" }
    apply         = { name = "alz-apply", yml = "pipelines/azure-devops/alz-apply.yml" }
    drift         = { name = "alz-drift-detection", yml = "pipelines/azure-devops/alz-drift-detection.yml" }
  }
}

#------------------------------------------------------------------------------
# Service connections (Workload Identity Federation, manual = bring your app)
#------------------------------------------------------------------------------
resource "azuredevops_serviceendpoint_azurerm" "this" {
  for_each = local.identities

  project_id                             = data.azuredevops_project.this.id
  service_endpoint_name                  = each.value.name
  description                            = each.value.description
  service_endpoint_authentication_scheme = "WorkloadIdentityFederation"
  azurerm_spn_tenantid                   = var.tenant_id
  azurerm_management_group_id            = var.root_parent_management_group_id
  azurerm_management_group_name          = var.root_parent_management_group_name

  credentials {
    serviceprincipalid = each.value.client_id
  }
}

# Entra ID trusts exactly these service connections (issuer + subject).
resource "azuread_application_federated_identity_credential" "this" {
  for_each = local.identities

  application_id = each.value.application
  display_name   = "azure-devops-${each.value.name}"
  description    = "Azure DevOps service connection ${each.value.name} (project ${var.project_name})."
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = azuredevops_serviceendpoint_azurerm.this[each.key].workload_identity_federation_issuer
  subject        = azuredevops_serviceendpoint_azurerm.this[each.key].workload_identity_federation_subject
}

#------------------------------------------------------------------------------
# Non-secret pipeline configuration
#------------------------------------------------------------------------------
resource "azuredevops_variable_group" "alz" {
  project_id   = data.azuredevops_project.this.id
  name         = "alz-iac"
  description  = "Identifiers for the ALZ pipelines (no secrets - OIDC only). Managed by Terraform."
  allow_access = false

  variable {
    name  = "AZURE_TENANT_ID"
    value = var.tenant_id
  }
  variable {
    name  = "AZURE_SUBSCRIPTION_ID"
    value = var.bootstrap_subscription_id
  }
  variable {
    name  = "TF_STATE_RESOURCE_GROUP"
    value = var.state_resource_group_name
  }
  variable {
    name  = "TF_STATE_STORAGE_ACCOUNT"
    value = var.state_storage_account_name
  }
  variable {
    name  = "PLAN_SERVICE_CONNECTION_ID"
    value = azuredevops_serviceendpoint_azurerm.this["plan"].id
  }
  variable {
    name  = "APPLY_SERVICE_CONNECTION_ID"
    value = azuredevops_serviceendpoint_azurerm.this["apply"].id
  }
}

#------------------------------------------------------------------------------
# Environment and checks (gates cannot be bypassed by editing YAML)
#------------------------------------------------------------------------------
resource "azuredevops_environment" "production" {
  project_id  = data.azuredevops_project.this.id
  name        = var.environment_name
  description = "ALZ production applies. Approvals + exclusive lock. Managed by Terraform."
}

resource "azuredevops_check_approval" "production" {
  project_id                 = data.azuredevops_project.this.id
  target_resource_id         = azuredevops_environment.production.id
  target_resource_type       = "environment"
  approvers                  = var.approver_ids
  minimum_required_approvers = 1
  requester_can_approve      = false
  instructions               = "Review the published plan (Plan stage summary and tfplan artifact) before approving. Generated reference - untested."
  timeout                    = 1440
}

resource "azuredevops_check_exclusive_lock" "production" {
  project_id           = data.azuredevops_project.this.id
  target_resource_id   = azuredevops_environment.production.id
  target_resource_type = "environment"
  timeout              = 1440
}

resource "azuredevops_check_branch_control" "apply_connection" {
  project_id                       = data.azuredevops_project.this.id
  display_name                     = "Only main may use the ALZ apply identity"
  target_resource_id               = azuredevops_serviceendpoint_azurerm.this["apply"].id
  target_resource_type             = "endpoint"
  allowed_branches                 = var.repository.branch
  verify_branch_protection         = true
  ignore_unknown_protection_status = false
}

resource "azuredevops_check_branch_control" "environment" {
  project_id                       = data.azuredevops_project.this.id
  display_name                     = "Only main may deploy to ${var.environment_name}"
  target_resource_id               = azuredevops_environment.production.id
  target_resource_type             = "environment"
  allowed_branches                 = var.repository.branch
  verify_branch_protection         = true
  ignore_unknown_protection_status = false
}

#------------------------------------------------------------------------------
# Pipelines (YAML lives in the repository)
#------------------------------------------------------------------------------
data "azuredevops_git_repository" "azure_repos" {
  count = var.repository.type == "TfsGit" ? 1 : 0

  project_id = data.azuredevops_project.this.id
  name       = var.repository.id
}

locals {
  repo_id = var.repository.type == "TfsGit" ? data.azuredevops_git_repository.azure_repos[0].id : var.repository.id
}

resource "azuredevops_build_definition" "this" {
  for_each = local.pipelines

  project_id      = data.azuredevops_project.this.id
  name            = each.value.name
  path            = "\\azure-landing-zones"
  variable_groups = [azuredevops_variable_group.alz.id]

  repository {
    repo_type             = var.repository.type
    repo_id               = local.repo_id
    branch_name           = var.repository.branch
    yml_path              = each.value.yml
    service_connection_id = var.repository.type == "GitHub" ? var.repository.service_connection_id : null
  }

  ci_trigger {
    use_yaml = true
  }

  dynamic "pull_request_trigger" {
    for_each = each.key == "pr_validation" && var.repository.type == "GitHub" ? [1] : []
    content {
      use_yaml = true
      forks {
        enabled       = false
        share_secrets = false
      }
    }
  }
}

# Azure Repos ignores YAML `pr` triggers: enforce PR validation by policy.
resource "azuredevops_branch_policy_build_validation" "pr_validation" {
  count = var.repository.type == "TfsGit" ? 1 : 0

  project_id = data.azuredevops_project.this.id
  enabled    = true
  blocking   = true

  settings {
    display_name        = "ALZ plan must succeed"
    build_definition_id = azuredevops_build_definition.this["pr_validation"].id
    valid_duration      = 720
    filename_patterns   = ["/code/*", "/pipelines/*", "/.tflint.hcl"]

    scope {
      repository_id  = local.repo_id
      repository_ref = var.repository.branch
      match_type     = "Exact"
    }
  }
}

#------------------------------------------------------------------------------
# Least-privilege pipeline authorisations
#------------------------------------------------------------------------------
resource "azuredevops_pipeline_authorization" "plan_connection" {
  for_each = local.pipelines

  project_id  = data.azuredevops_project.this.id
  resource_id = azuredevops_serviceendpoint_azurerm.this["plan"].id
  type        = "endpoint"
  pipeline_id = azuredevops_build_definition.this[each.key].id
}

resource "azuredevops_pipeline_authorization" "apply_connection" {
  project_id  = data.azuredevops_project.this.id
  resource_id = azuredevops_serviceendpoint_azurerm.this["apply"].id
  type        = "endpoint"
  pipeline_id = azuredevops_build_definition.this["apply"].id
}

resource "azuredevops_pipeline_authorization" "environment" {
  project_id  = data.azuredevops_project.this.id
  resource_id = azuredevops_environment.production.id
  type        = "environment"
  pipeline_id = azuredevops_build_definition.this["apply"].id
}

resource "azuredevops_pipeline_authorization" "variable_group" {
  for_each = local.pipelines

  project_id  = data.azuredevops_project.this.id
  resource_id = azuredevops_variable_group.alz.id
  type        = "variablegroup"
  pipeline_id = azuredevops_build_definition.this[each.key].id
}
