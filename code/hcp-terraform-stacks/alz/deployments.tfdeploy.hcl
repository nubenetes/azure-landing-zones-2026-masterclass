# -----------------------------------------------------------------------------
# Terraform Stack "alz" - deployments
#
# Generated with Claude Opus 5.5 - architectural reference, NOT tested in a
# live environment (passes `terraform stacks validate` in CI only).
#
#   canary      isolated "canary-" management group hierarchy in the same
#               tenant, own platform subscriptions, cheap SKUs, FULL policy
#               enforcement. Auto-approved when nothing is destroyed
#               (deployment_auto_approve requires HCP Terraform Premium).
#   production  the real hierarchy. Always a human approval in HCP Terraform.
#
# Each deployment has its own isolated state. The Day 0 apply app trusts
#   organization:<org>:project:<project>:stack:alz:deployment:<name>:operation:{plan|apply}
# GUIDs below are documentation placeholders.
# -----------------------------------------------------------------------------

identity_token "azure" {
  audience = ["api://AzureADTokenExchange"]
}

locals {
  tenant_id       = "00000000-0000-0000-0000-000000000000"
  apply_client_id = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb" # Day 0 output apply_identity.client_id

  common_tags = {
    managed_by   = "terraform-stacks"
    stack        = "alz"
    generated_by = "claude-opus-5.5"
    tested       = "false"
  }
}

#------------------------------------------------------------------------------
# Canary - validate platform and policy changes before production
#------------------------------------------------------------------------------
deployment "canary" {
  inputs = {
    identity_token = identity_token.azure.jwt
    tenant_id      = local.tenant_id
    client_id      = local.apply_client_id

    root_parent_management_group_id = local.tenant_id
    architecture_name               = "alz_2026_masterclass_canary"
    management_group_id_prefix      = "canary-"

    platform_subscription_ids = {
      management   = "c1111111-1111-1111-1111-111111111111"
      connectivity = "c2222222-2222-2222-2222-222222222222"
      identity     = "c3333333-3333-3333-3333-333333333333"
    }

    # Isolated: never peered or connected to on-premises, so it may reuse
    # the production address plan.
    regions = {
      primary = {
        location     = "westeurope"
        short_name   = "weu"
        index        = 0
        is_primary   = true
        firewall_sku = "Basic"
      }
    }
    connectivity_type = "hub_and_spoke_vnet"
    connectivity_features = {
      ddos_protection_plan = false
      bastion              = false
      vpn_gateway          = false
      expressroute_gateway = false
    }

    log_analytics_retention_in_days = 30
    security_contact_email          = "secops@example.com"
    policy_enforcement_phase        = "enforce" # canary always runs the strictest phase
    allowed_locations               = ["westeurope"]
    tags                            = merge(local.common_tags, { environment = "canary" })

    workload_landing_zones = {
      canary-probe = {
        display_name             = "Canary probe workload"
        archetype                = "corp"
        environment              = "nonprod"
        region_key               = "primary"
        spoke_index              = 0
        existing_subscription_id = "c4444444-4444-4444-4444-444444444444"
        owner_group_object_id    = "55555555-5555-5555-5555-555555555555"
        cost_center              = "platform-0001"
        budget_amount            = 200
        budget_contact_emails    = ["platform@example.com"]
      }
    }
  }

  deployment_group = deployment_group.canary
}

#------------------------------------------------------------------------------
# Production
#------------------------------------------------------------------------------
deployment "production" {
  inputs = {
    identity_token = identity_token.azure.jwt
    tenant_id      = local.tenant_id
    client_id      = local.apply_client_id

    root_parent_management_group_id = local.tenant_id
    architecture_name               = "alz_2026_masterclass"
    management_group_id_prefix      = ""

    platform_subscription_ids = {
      management   = "11111111-1111-1111-1111-111111111111"
      connectivity = "22222222-2222-2222-2222-222222222222"
      identity     = "33333333-3333-3333-3333-333333333333"
      security     = "44444444-4444-4444-4444-444444444444"
    }

    regions = {
      primary = {
        location   = "westeurope"
        short_name = "weu"
        index      = 0
        is_primary = true
      }
      secondary = {
        location   = "northeurope"
        short_name = "neu"
        index      = 1
      }
    }
    connectivity_type = "hub_and_spoke_vnet"
    connectivity_features = {
      expressroute_gateway = true
    }

    log_analytics_retention_in_days    = 90
    sentinel_enabled                   = true
    security_contact_email             = "secops@example.com"
    policy_enforcement_phase           = "audit" # promote via PR: audit -> remediate -> enforce
    allowed_locations                  = ["westeurope", "northeurope"]
    platform_operators_group_object_id = "55555555-5555-5555-5555-555555555555"
    tags                               = merge(local.common_tags, { environment = "production" })

    subscription_billing_scope = "/providers/Microsoft.Billing/billingAccounts/1234567/enrollmentAccounts/7654321"
    hub_gateways_present       = true
    workload_landing_zones = {
      payments-prod = {
        display_name          = "Payments API - Production"
        archetype             = "corp"
        environment           = "prod"
        region_key            = "primary"
        spoke_index           = 0
        owner_group_object_id = "66666666-6666-6666-6666-666666666666"
        cost_center           = "cc-payments-1001"
        budget_amount         = 4000
        budget_contact_emails = ["payments-leads@example.com", "finops@example.com"]
        github_repository     = "nubenetes/payments-api"
      }
    }
  }

  # No deployment_group: production lands in its default group and every
  # plan waits for a human approval in HCP Terraform.
}

#------------------------------------------------------------------------------
# Auto-approval for the canary only (HCP Terraform Premium feature)
#------------------------------------------------------------------------------
deployment_auto_approve "no_destroys" {
  check {
    condition = context.plan.changes.remove == 0
    reason    = "Plan removes ${context.plan.changes.remove} resources - manual review required."
  }
}

deployment_auto_approve "plan_is_applyable" {
  check {
    condition = context.plan.applyable
    reason    = "Plan is not applyable."
  }
}

deployment_group "canary" {
  auto_approve_checks = [
    deployment_auto_approve.no_destroys,
    deployment_auto_approve.plan_is_applyable,
  ]
}
