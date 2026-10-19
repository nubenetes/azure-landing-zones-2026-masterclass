###############################################################################
# Day 0 (optional) - HCP Terraform / Terraform Enterprise: outputs
###############################################################################

output "project_id" {
  description = "HCP Terraform / TFE project ID."
  value       = tfe_project.alz.id
}

output "workspace_ids" {
  description = "Workspace IDs (delivery_model = workspaces | both)."
  value       = { for k, w in tfe_workspace.this : k => w.id }
}

output "stack_id" {
  description = "Stack ID (delivery_model = stacks | both)."
  value       = one(concat(tfe_stack.alz_github_app[*].id, tfe_stack.alz_oauth[*].id))
}
