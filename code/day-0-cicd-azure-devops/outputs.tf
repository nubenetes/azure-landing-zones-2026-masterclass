###############################################################################
# Day 0 (optional) - Azure DevOps delivery: outputs
###############################################################################

output "service_connections" {
  description = "Service connection IDs and the federated subjects Entra ID now trusts."
  value = {
    for k, sc in azuredevops_serviceendpoint_azurerm.this : k => {
      id      = sc.id
      issuer  = sc.workload_identity_federation_issuer
      subject = sc.workload_identity_federation_subject
    }
  }
}

output "pipelines" {
  description = "Pipeline definition IDs."
  value       = { for k, p in azuredevops_build_definition.this : k => p.id }
}

output "environment_id" {
  description = "ID of the gated environment."
  value       = azuredevops_environment.production.id
}
