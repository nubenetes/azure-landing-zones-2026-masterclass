###############################################################################
# Day 1 - Platform Landing Zone: outputs (re-exported platform contract)
# Day 2 reads these through remote state; names are a versioned contract.
###############################################################################

output "management_group_resource_ids" {
  description = "Management group resource IDs keyed by management group name."
  value       = module.platform.management_group_resource_ids
}

output "management_group_ids" {
  description = "Management group IDs keyed by role (alz, platform, landingzones, corp, online, sandbox, ...), including any prefix."
  value       = module.platform.management_group_ids
}

output "connectivity_type" {
  description = "Deployed network topology."
  value       = module.platform.connectivity_type
}

output "primary_location" {
  description = "Primary platform region."
  value       = module.platform.primary_location
}

output "ipam_plan" {
  description = "Deterministic address plan: per region, the /12 supernet and the /16 block reserved for every landing zone archetype."
  value       = module.platform.ipam_plan
}

output "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace resource ID."
  value       = module.platform.log_analytics_workspace_id
}

output "hub_virtual_network_resource_ids" {
  description = "Hub VNet resource IDs keyed by region key (hub-and-spoke only)."
  value       = module.platform.hub_virtual_network_resource_ids
}

output "virtual_hub_resource_ids" {
  description = "Virtual WAN hub resource IDs keyed by region key (Virtual WAN only)."
  value       = module.platform.virtual_hub_resource_ids
}

output "dns_server_ip_addresses" {
  description = "IP addresses spokes must use as DNS servers, keyed by region key (Azure Firewall DNS proxy in hub-and-spoke, resolver/firewall in vWAN)."
  value       = module.platform.dns_server_ip_addresses
}

output "firewall_private_ip_addresses" {
  description = "Azure Firewall private IPs keyed by region key (next hop for spoke UDRs in hub-and-spoke)."
  value       = module.platform.firewall_private_ip_addresses
}

output "private_dns_zone_resource_ids" {
  description = "Central Private Link DNS zones (Connectivity subscription)."
  value       = module.platform.private_dns_zone_resource_ids
}

output "policy_assignment_identity_ids" {
  description = "Principal IDs of the policy assignment managed identities (mg/assignment => principal)."
  value       = module.platform.policy_assignment_identity_ids
}
