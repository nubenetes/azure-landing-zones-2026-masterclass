###############################################################################
# Day 2 - Workload vending & operations: outputs
# Handed back to each workload team (e.g. posted on the vending PR).
###############################################################################

output "workload_landing_zones" {
  description = "Per landing zone: subscription, network and identity details for the workload team."
  value       = module.workloads.workload_landing_zones
}

output "workload_guardrails_assignment_id" {
  description = "Resource ID of the workload guardrails initiative assignment."
  value       = module.workloads.workload_guardrails_assignment_id
}

output "policy_enforcement_phase" {
  description = "Current rollout phase of the workload guardrails."
  value       = module.workloads.policy_enforcement_phase
}
