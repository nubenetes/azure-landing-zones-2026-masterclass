###############################################################################
# Day 1 - Platform Landing Zone: outputs
# Consumed by Day 2 through `terraform_remote_state` - treat this file as a
# versioned contract between the platform and the vending stages.
###############################################################################

output "management_group_resource_ids" {
  description = "Management group resource IDs keyed by management group name."
  value       = module.alz.management_group_resource_ids
}

output "connectivity_type" {
  description = "Deployed network topology."
  value       = var.connectivity_type
}

output "primary_location" {
  description = "Primary platform region."
  value       = local.primary_location
}

output "ipam_plan" {
  description = "Deterministic address plan: per region, the /12 supernet and the /16 block reserved for every landing zone archetype."
  value       = local.ipam_plan
}

output "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace resource ID."
  value       = local.log_analytics_workspace_id
}

output "hub_virtual_network_resource_ids" {
  description = "Hub VNet resource IDs keyed by region key (hub-and-spoke only)."
  value       = one([for m in module.hub_and_spoke : m.virtual_network_resource_ids])
}

output "virtual_hub_resource_ids" {
  description = "Virtual WAN hub resource IDs keyed by region key (Virtual WAN only)."
  value       = one([for m in module.virtual_wan : m.virtual_hub_resource_ids])
}

output "dns_server_ip_addresses" {
  description = "IP addresses spokes must use as DNS servers, keyed by region key (Azure Firewall DNS proxy in hub-and-spoke, resolver/firewall in vWAN)."
  # one(concat(...)) selects the single deployed topology without forcing the
  # two modules' output types to unify in a conditional expression.
  value = one(concat(
    [for m in module.hub_and_spoke : m.dns_server_ip_addresses],
    [for m in module.virtual_wan : m.dns_server_ip_address],
  ))
}

output "firewall_private_ip_addresses" {
  description = "Azure Firewall private IPs keyed by region key (next hop for spoke UDRs in hub-and-spoke)."
  value = one(concat(
    [for m in module.hub_and_spoke : m.firewall_private_ip_addresses],
    [for m in module.virtual_wan : m.firewall_private_ip_address],
  ))
}

output "private_dns_zone_resource_ids" {
  description = "Central Private Link DNS zones (Connectivity subscription)."
  value = one(concat(
    [for m in module.hub_and_spoke : m.private_dns_zone_resource_ids],
    [for m in module.virtual_wan : m.private_dns_zone_resource_ids],
  ))
}

output "policy_assignment_identity_ids" {
  description = "Principal IDs of the policy assignment managed identities (mg/assignment => principal)."
  value       = module.alz.policy_assignment_identity_ids
}
