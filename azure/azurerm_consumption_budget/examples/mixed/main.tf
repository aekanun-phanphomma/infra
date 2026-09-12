###############################################################################
# Example: FOUR budgets across THREE different scopes, from ONE module call.
#
#   Budget A (platform)        -> subscription
#   Budget B (openai)          -> resource group
#   Budget C (azure_foundry)   -> resource group
#   Budget D (enterprise)      -> management group
#
# Terraform creates three different resource types from this single call:
#
#   azurerm_consumption_budget_subscription.this["platform"]
#   azurerm_consumption_budget_resource_group.this["openai"]
#   azurerm_consumption_budget_resource_group.this["azure_foundry"]
#   azurerm_consumption_budget_management_group.this["enterprise"]
#
# Note how the management group budget uses ONLY contact_emails, while the
# subscription and resource group budgets can also use contact_groups and
# contact_roles. That asymmetry is the provider schema, not a module choice.
###############################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_guid
}

locals {
  subscription_id = "/subscriptions/${var.subscription_guid}"
  rg_id_prefix    = "/subscriptions/${var.subscription_guid}/resourceGroups"
}

module "consumption_budgets" {
  source = "../../"

  budgets = {
    #--- Budget A: subscription scope ---------------------------------------
    platform = {
      scope_type      = "subscription"
      subscription_id = local.subscription_id

      name       = "budget-platform"
      amount     = 5000
      time_grain = "Monthly"

      time_period = {
        start_date = var.budget_start_date
      }

      notifications = {
        warning = {
          threshold      = 50
          contact_emails = ["platform@example.com"]
        }

        critical = {
          threshold      = 90
          contact_emails = ["platform@example.com", "finance@example.com"]
          # Valid at subscription scope.
          contact_roles = ["Owner"]
        }
      }
    }

    #--- Budget B: resource group scope --------------------------------------
    openai = {
      scope_type        = "resource_group"
      resource_group_id = "${local.rg_id_prefix}/rg-openai"

      name       = "budget-openai"
      amount     = 1000
      time_grain = "Monthly"

      time_period = {
        start_date = var.budget_start_date
      }

      notifications = {
        warning = {
          threshold      = 50
          contact_emails = ["owner@example.com", "devops@example.com"]
        }

        critical = {
          threshold      = 80
          contact_emails = ["owner@example.com", "devops@example.com", "finance@example.com"]
        }
      }
    }

    #--- Budget C: resource group scope, same subscription -------------------
    azure_foundry = {
      scope_type        = "resource_group"
      resource_group_id = "${local.rg_id_prefix}/rg-azure-foundry"

      name       = "budget-azure-foundry"
      amount     = 2000
      time_grain = "Quarterly"

      time_period = {
        start_date = var.budget_start_date
      }

      notifications = {
        warning = {
          threshold      = 50
          contact_emails = ["owner@example.com", "devops@example.com"]
        }

        critical = {
          threshold      = 80
          contact_emails = ["owner@example.com", "finance@example.com"]
        }
      }

      # Narrow this budget to spend tagged for one cost centre.
      filter = {
        tag = [
          {
            name   = "costCenter"
            values = ["cc-ai-platform"]
          },
        ]
      }
    }

    #--- Budget D: management group scope ------------------------------------
    enterprise = {
      scope_type          = "management_group"
      management_group_id = "/providers/Microsoft.Management/managementGroups/${var.management_group_name}"

      name       = "budget-enterprise"
      amount     = 50000
      time_grain = "Monthly"

      time_period = {
        start_date = var.budget_start_date
      }

      notifications = {
        # contact_emails only: contact_groups and contact_roles do not exist
        # on azurerm_consumption_budget_management_group.
        warning = {
          threshold      = 75
          contact_emails = ["finance@example.com"]
        }

        exceeded = {
          threshold      = 100
          operator       = "GreaterThanOrEqualTo"
          contact_emails = ["finance@example.com", "cto@example.com"]
        }
      }
    }
  }
}

output "budget_ids" {
  description = "Logical budget key -> Azure budget resource ID, flattened across all three scopes."
  value       = module.consumption_budgets.budget_ids
}

output "budget_ids_by_scope" {
  description = "The same IDs grouped by scope type."
  value       = module.consumption_budgets.budget_ids_by_scope
}

output "budget_scope_types" {
  description = "Which scope each logical budget key was routed to."
  value       = module.consumption_budgets.budget_scope_types
}
