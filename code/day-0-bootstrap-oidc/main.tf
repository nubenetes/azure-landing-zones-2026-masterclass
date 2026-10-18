###############################################################################
# Day 0 - Bootstrap: remote state + Workload Identity Federation (OIDC)
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment. Validate in a sandbox tenant before any real use.
#
# Security posture enforced here:
#   * No client secrets anywhere: GitHub Actions authenticates with OIDC.
#   * Two CI/CD identities with separation of duties:
#       - "plan"  : read-only on Azure + read-only on state (PR + main plans).
#       - "apply" : write, but ONLY reachable from the protected GitHub
#                   Environment (required reviewers) - never from a PR.
#   * State storage: Shared Key disabled, Entra ID-only data-plane auth,
#     CMK in Key Vault with auto-rotation, versioning + soft delete.
###############################################################################

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

locals {
  suffix = random_string.suffix.result

  # Names
  resource_group_name  = "rg-${var.name_prefix}-iac-state-${var.location}"
  storage_account_name = "st${var.name_prefix}tfstate${local.suffix}"
  key_vault_name       = "kv-${var.name_prefix}-tfs-${local.suffix}"
  storage_uami_name    = "id-${var.name_prefix}-tfstate-cmk"

  root_parent_mg_scope = "/providers/Microsoft.Management/managementGroups/${var.root_parent_management_group_id}"

  # GitHub OIDC
  github_issuer  = "https://token.actions.githubusercontent.com"
  github_aud     = ["api://AzureADTokenExchange"]
  subject_prefix = "repo:${var.github_organization}/${var.github_repository}"

  # Subjects trusted by the read-only PLAN identity:
  #   - any pull request targeting the repository
  #   - the protected default branch (pre-apply plans & drift detection)
  plan_subjects = {
    pull-request   = "${local.subject_prefix}:pull_request"
    default-branch = "${local.subject_prefix}:ref:refs/heads/${var.github_default_branch}"
  }

  # Subjects trusted by the privileged APPLY identity:
  #   - ONLY jobs bound to the protected GitHub Environment.
  apply_subjects = {
    protected-environment = "${local.subject_prefix}:environment:${var.github_apply_environment}"
  }
}

###############################################################################
# Resource group
###############################################################################

resource "azurerm_resource_group" "state" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_management_lock" "state_rg" {
  name       = "lock-cannot-delete-iac-state"
  scope      = azurerm_resource_group.state.id
  lock_level = "CanNotDelete"
  notes      = "Protects Terraform remote state for the Azure Landing Zone. Remove only through change control."
}

###############################################################################
# Key Vault + customer-managed key (CMK) for state encryption
###############################################################################

resource "azurerm_key_vault" "state" {
  name                          = local.key_vault_name
  location                      = azurerm_resource_group.state.location
  resource_group_name           = azurerm_resource_group.state.name
  tenant_id                     = var.tenant_id
  sku_name                      = "premium" # HSM-backed keys available
  rbac_authorization_enabled    = true      # No access policies - Azure RBAC only
  purge_protection_enabled      = true      # Mandatory for storage CMK
  soft_delete_retention_days    = 90
  public_network_access_enabled = true # Restricted by network_acls below

  network_acls {
    bypass         = "AzureServices" # Lets Azure Storage reach the key for CMK wrap/unwrap
    default_action = length(var.operator_ip_cidrs) > 0 ? "Deny" : "Allow"
    ip_rules       = var.operator_ip_cidrs
  }

  tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

# The operator running Day 0 needs to create the key.
resource "azurerm_role_assignment" "operator_kv_crypto_officer" {
  scope                = azurerm_key_vault.state.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
  description          = "Day 0 operator - creates and rotates the Terraform state CMK."
}

resource "azurerm_user_assigned_identity" "storage_cmk" {
  name                = local.storage_uami_name
  location            = azurerm_resource_group.state.location
  resource_group_name = azurerm_resource_group.state.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "storage_uami_kv_crypto_user" {
  scope                = azurerm_key_vault.state.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.storage_cmk.principal_id
  principal_type       = "ServicePrincipal"
  description          = "Allows the state storage account to wrap/unwrap its CMK."
}

# Azure RBAC is eventually consistent; give role assignments time to propagate.
resource "time_sleep" "kv_rbac_propagation" {
  create_duration = "90s"

  depends_on = [
    azurerm_role_assignment.operator_kv_crypto_officer,
    azurerm_role_assignment.storage_uami_kv_crypto_user,
  ]
}

resource "azurerm_key_vault_key" "state" {
  name         = "cmk-tfstate"
  key_vault_id = azurerm_key_vault.state.id
  key_type     = "RSA-HSM"
  key_size     = 4096
  key_opts     = ["wrapKey", "unwrapKey"]

  rotation_policy {
    expire_after         = "P2Y"
    notify_before_expiry = "P30D"

    automatic {
      time_after_creation = var.key_rotation_period
    }
  }

  tags       = var.tags
  depends_on = [time_sleep.kv_rbac_propagation]

  lifecycle {
    prevent_destroy = true
  }
}

###############################################################################
# State storage account (Entra ID-only, CMK, versioning, soft delete)
###############################################################################

resource "azurerm_storage_account" "state" {
  name                     = local.storage_account_name
  location                 = azurerm_resource_group.state.location
  resource_group_name      = azurerm_resource_group.state.name
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "GZRS"

  # Identity-first data plane
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  local_user_enabled              = false

  # Hardening
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  allow_nested_items_to_be_public   = false
  cross_tenant_replication_enabled  = false
  infrastructure_encryption_enabled = true
  allowed_copy_scope                = "AAD"
  public_network_access_enabled     = var.state_storage_public_network_access_enabled

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage_cmk.id]
  }

  customer_managed_key {
    # Versionless ID => the account follows automatic key rotation.
    key_vault_key_id          = azurerm_key_vault_key.state.versionless_id
    user_assigned_identity_id = azurerm_user_assigned_identity.storage_cmk.id
  }

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action = "Allow" # See variable description: GitHub-hosted runners have dynamic IPs.
    bypass         = ["AzureServices", "Logging", "Metrics"]
  }

  tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "state" {
  for_each = var.state_containers

  name                  = each.value
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

# The Day 0 operator owns the data plane (needed to migrate bootstrap state).
resource "azurerm_role_assignment" "operator_blob_owner" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
  description          = "Day 0 operator - initial state migration and break-glass recovery."
}

###############################################################################
# Entra ID: App Registrations + Service Principals (no secrets, OIDC only)
###############################################################################

resource "azuread_application_registration" "plan" {
  display_name     = "sp-${var.name_prefix}-alz-cicd-plan"
  description      = "ALZ CI/CD - read-only PLAN identity (GitHub OIDC). Generated reference: ${var.github_organization}/${var.github_repository}."
  sign_in_audience = "AzureADMyOrg"
  notes            = "No client secrets or certificates may be added. Federated credentials only."
}

resource "azuread_application_registration" "apply" {
  display_name     = "sp-${var.name_prefix}-alz-cicd-apply"
  description      = "ALZ CI/CD - privileged APPLY identity (GitHub OIDC, protected environment only)."
  sign_in_audience = "AzureADMyOrg"
  notes            = "No client secrets or certificates may be added. Federated credentials only."
}

resource "azuread_service_principal" "plan" {
  client_id                    = azuread_application_registration.plan.client_id
  app_role_assignment_required = false
  owners                       = [data.azurerm_client_config.current.object_id]
  description                  = "ALZ CI/CD read-only plan identity."
}

resource "azuread_service_principal" "apply" {
  client_id                    = azuread_application_registration.apply.client_id
  app_role_assignment_required = false
  owners                       = [data.azurerm_client_config.current.object_id]
  description                  = "ALZ CI/CD privileged apply identity."
}

###############################################################################
# Federated Identity Credentials (Workload Identity Federation)
###############################################################################

resource "azuread_application_federated_identity_credential" "plan" {
  for_each = local.plan_subjects

  application_id = azuread_application_registration.plan.id
  display_name   = "github-${var.github_repository}-${each.key}"
  description    = "GitHub Actions OIDC trust (${each.key}) for read-only plans."
  audiences      = local.github_aud
  issuer         = local.github_issuer
  subject        = each.value
}

resource "azuread_application_federated_identity_credential" "apply" {
  for_each = local.apply_subjects

  application_id = azuread_application_registration.apply.id
  display_name   = "github-${var.github_repository}-${each.key}"
  description    = "GitHub Actions OIDC trust (${each.key}) for gated applies."
  audiences      = local.github_aud
  issuer         = local.github_issuer
  subject        = each.value
}

###############################################################################
# Azure RBAC for the CI/CD identities
###############################################################################

# PLAN: read-only on the management plane below the root parent MG.
resource "azurerm_role_assignment" "plan_reader_root" {
  scope                = local.root_parent_mg_scope
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.plan.object_id
  principal_type       = "ServicePrincipal"
  description          = "ALZ CI/CD plan identity - read-only management plane."
}

# PLAN: read-only on state. PR plans run with -lock=false, so no write access
# (and therefore no ability to tamper with state) is granted to PR workflows.
resource "azurerm_role_assignment" "plan_state_reader" {
  for_each = azurerm_storage_container.state

  scope                = each.value.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azuread_service_principal.plan.object_id
  principal_type       = "ServicePrincipal"
  description          = "ALZ CI/CD plan identity - read state (${each.key})."
}

# APPLY: Owner at the root parent MG is required by the ALZ pattern module to
# create management groups, policy assignments AND the role assignments for
# DeployIfNotExists/Modify managed identities.
#
# The ABAC delegation condition below (pattern recommended by the AVM ALZ
# module) blocks the pipeline from creating OR deleting assignments of the
# three privileged roles: Owner (8e3af657...), User Access Administrator
# (18d7d88d...) and Role Based Access Control Administrator (f58310d9...).
# A compromised pipeline therefore cannot mint new standing owners.
locals {
  privileged_role_guids = "8e3af657-a8ff-443c-a75c-2fe8c4bcb635, 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9, f58310d9-a9f6-439a-9e8d-f62e7b41a168"
  apply_rbac_condition  = "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'}))OR(@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId]ForAnyOfAllValues:GuidNotEquals{${local.privileged_role_guids}}))AND((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'}))OR(@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId]ForAnyOfAllValues:GuidNotEquals{${local.privileged_role_guids}}))"
}

resource "azurerm_role_assignment" "apply_owner_root" {
  scope                = local.root_parent_mg_scope
  role_definition_name = "Owner"
  principal_id         = azuread_service_principal.apply.object_id
  principal_type       = "ServicePrincipal"
  description          = "ALZ CI/CD apply identity - platform landing zone deployment (privileged-role delegation blocked by ABAC condition)."
  condition            = var.apply_identity_rbac_condition_enabled ? local.apply_rbac_condition : null
  condition_version    = var.apply_identity_rbac_condition_enabled ? "2.0" : null
}

resource "azurerm_role_assignment" "apply_state_contributor" {
  for_each = azurerm_storage_container.state

  scope                = each.value.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.apply.object_id
  principal_type       = "ServicePrincipal"
  description          = "ALZ CI/CD apply identity - read/write/lock state (${each.key})."
}

resource "azurerm_role_assignment" "additional_state_readers" {
  for_each = var.additional_state_readers

  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = each.value
  description          = "Additional state reader: ${each.key}."
}
