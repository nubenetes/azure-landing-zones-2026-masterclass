# -----------------------------------------------------------------------------
# Terraform Stack "alz" - outputs
# -----------------------------------------------------------------------------

output "management_group_resource_ids" {
  type        = map(string)
  description = "Management groups of this deployment."
  value       = component.platform.management_group_resource_ids
}

# Stack outputs need exact types (`any` is rejected).
output "ipam_plan" {
  type = map(object({
    location        = string
    region_supernet = string
    blocks          = map(string)
  }))
  description = "Deterministic address plan of this deployment."
  value       = component.platform.ipam_plan
}

output "workload_landing_zones" {
  type = map(object({
    subscription_id    = string
    management_group   = string
    location           = string
    spoke_cidr         = string
    subnets            = map(string)
    dns_servers        = list(string)
    virtual_network_id = string
    deploy_identity = object({
      client_id    = string
      principal_id = string
    })
  }))
  description = "Vended workload landing zones (subscription, network, identity)."
  value       = component.workloads.workload_landing_zones
}
