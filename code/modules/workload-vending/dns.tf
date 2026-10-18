###############################################################################
# Module: workload-vending - Private DNS zone linking (exception path)
#
# DEFAULT PATTERN (no links needed):
#   spoke VNet DNS = Azure Firewall DNS proxy (hub-and-spoke) or hub resolver
#   -> Azure DNS Private Resolver inbound endpoint (Connectivity)
#   -> central privatelink.* zones linked to the hub / sidecar VNet.
#   Private Endpoint A-records are written into the central zones by the ALZ
#   "Deploy-Private-DNS-Zones" DeployIfNotExists assignment at the Corp MG.
#
# EXCEPTION PATH (this file):
#   some workloads must resolve Private Link names WITHOUT traversing the hub
#   (e.g. isolated online landing zones, latency-sensitive data platforms or
#   vWAN spokes without a resolver). For those, `private_dns_zone_links = true`
#   links every central zone to the spoke VNet, with NxDomainRedirect so that
#   names without a private record still fall back to public resolution.
###############################################################################

locals {
  # Central zones of the spoke's region, flattened to { "<lz>|<zone_key>" => zone_id }.
  # Keys come from remote state (known at plan time), values may be unknown.
  dns_zone_links = merge([
    for lz_key, lz in var.workload_landing_zones : {
      for zone_key, zone_id in try(local.platform.private_dns_zone_resource_ids[lz.region_key], {}) :
      "${lz_key}|${zone_key}" => {
        lz_key  = lz_key
        zone_id = zone_id
      }
    } if lz.private_dns_zone_links && lz.archetype != "sandbox"
  ]...)
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  for_each = local.dns_zone_links

  name                  = "link-${each.value.lz_key}"
  resource_group_name   = provider::azapi::parse_resource_id("Microsoft.Network/privateDnsZones", each.value.zone_id).resource_group_name
  private_dns_zone_name = provider::azapi::parse_resource_id("Microsoft.Network/privateDnsZones", each.value.zone_id).name
  virtual_network_id    = module.workload_landing_zone[each.value.lz_key].virtual_network_resource_ids["spoke"]
  registration_enabled  = false
  resolution_policy     = "NxDomainRedirect"
  tags                  = local.lz[each.value.lz_key].tags

  provider = azurerm.connectivity
}
