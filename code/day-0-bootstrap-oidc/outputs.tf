###############################################################################
# Day 0 - Bootstrap: outputs
# None of these values are secrets (client IDs, tenant ID and resource names
# are identifiers, not credentials). They are safe to store as GitHub
# repository/environment *variables* (not secrets).
###############################################################################

output "state_resource_group_name" {
  description = "Resource group that hosts the Terraform remote state."
  value       = azurerm_resource_group.state.name
}

output "state_storage_account_name" {
  description = "Storage account that hosts the Terraform remote state."
  value       = azurerm_storage_account.state.name
}

output "state_containers" {
  description = "State containers by name."
  value       = { for k, v in azurerm_storage_container.state : k => v.id }
}

output "state_key_vault_id" {
  description = "Key Vault that holds the state CMK."
  value       = azurerm_key_vault.state.id
}

output "plan_identity" {
  description = "Read-only CI/CD identity (pull requests, pre-apply plans, drift detection)."
  value = {
    client_id = azuread_application_registration.plan.client_id
    object_id = azuread_service_principal.plan.object_id
  }
}

output "apply_identity" {
  description = "Privileged CI/CD identity (protected GitHub Environment only)."
  value = {
    client_id = azuread_application_registration.apply.client_id
    object_id = azuread_service_principal.apply.object_id
  }
}

output "backend_hcl" {
  description = "Partial backend configuration for later stages. Write it to backend.hcl and pass -backend-config=backend.hcl -backend-config=\"key=<stage>.tfstate\"."
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.state.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name       = "<one of: ${join(", ", sort(tolist(var.state_containers)))}>"
    use_azuread_auth     = true
    tenant_id           = "${var.tenant_id}"
    subscription_id      = "${var.bootstrap_subscription_id}"
  EOT
}

output "github_configuration_commands" {
  description = "GitHub CLI commands that configure the repository variables and the protected environment consumed by the workflows."
  value       = <<-EOT
    # Repository-level variables (identifiers only - no secrets are required with OIDC)
    gh variable set AZURE_TENANT_ID          --repo ${var.github_organization}/${var.github_repository} --body "${var.tenant_id}"
    gh variable set AZURE_SUBSCRIPTION_ID    --repo ${var.github_organization}/${var.github_repository} --body "${var.bootstrap_subscription_id}"
    gh variable set AZURE_PLAN_CLIENT_ID     --repo ${var.github_organization}/${var.github_repository} --body "${azuread_application_registration.plan.client_id}"
    gh variable set TF_STATE_RESOURCE_GROUP  --repo ${var.github_organization}/${var.github_repository} --body "${azurerm_resource_group.state.name}"
    gh variable set TF_STATE_STORAGE_ACCOUNT --repo ${var.github_organization}/${var.github_repository} --body "${azurerm_storage_account.state.name}"

    # Protected environment: the ONLY place the apply identity's client ID lives
    gh api --method PUT repos/${var.github_organization}/${var.github_repository}/environments/${var.github_apply_environment} \
      -f 'deployment_branch_policy[protected_branches]=true' -F 'deployment_branch_policy[custom_branch_policies]=false'
    gh variable set AZURE_APPLY_CLIENT_ID --repo ${var.github_organization}/${var.github_repository} --env ${var.github_apply_environment} --body "${azuread_application_registration.apply.client_id}"

    # Then, in the GitHub UI: Settings > Environments > ${var.github_apply_environment} > Required reviewers (platform team).
  EOT
}
