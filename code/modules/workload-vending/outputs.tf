###############################################################################
# Module: workload-vending - outputs
# Handed back to each workload team (e.g. posted on the vending PR).
###############################################################################

output "workload_landing_zones" {
  description = "Per landing zone: subscription, network and identity details for the workload team."
  value = {
    for k, m in module.workload_landing_zone : k => {
      subscription_id    = m.subscription_id
      management_group   = var.workload_landing_zones[k].archetype
      location           = local.lz[k].location
      spoke_cidr         = local.lz[k].spoke_cidr
      subnets            = local.subnet_layout[k]
      dns_servers        = local.lz[k].dns_servers
      virtual_network_id = try(m.virtual_network_resource_ids["spoke"], null)
      deploy_identity    = try({ client_id = m.umi_client_ids["deploy"], principal_id = m.umi_principal_ids["deploy"] }, null)
    }
  }
}

output "workload_guardrails_assignment_id" {
  description = "Resource ID of the workload guardrails initiative assignment."
  value       = azurerm_management_group_policy_assignment.workload_guardrails.id
}

output "policy_enforcement_phase" {
  description = "Current rollout phase of the workload guardrails."
  value       = var.policy_enforcement_phase
}
