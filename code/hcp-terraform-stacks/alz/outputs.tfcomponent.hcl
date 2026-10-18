# -----------------------------------------------------------------------------
# Terraform Stack "alz" - outputs
# -----------------------------------------------------------------------------

output "management_group_resource_ids" {
  type        = map(string)
  description = "Management groups of this deployment."
  value       = component.platform.management_group_resource_ids
}

output "ipam_plan" {
  type        = any
  description = "Deterministic address plan of this deployment."
  value       = component.platform.ipam_plan
}

output "workload_landing_zones" {
  type        = any
  description = "Vended workload landing zones (subscription, network, identity)."
  value       = component.workloads.workload_landing_zones
}
