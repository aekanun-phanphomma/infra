###############################################################################
# Example: a management-group-scoped consumption budget.
#
# IMPORTANT -- this scope has a REDUCED notification schema. The provider
# defines a separate notification model for
# azurerm_consumption_budget_management_group:
#
#   contact_emails  REQUIRED (MinItems 1)   <- Optional at the other scopes
#   contact_groups  DOES NOT EXIST
#   contact_roles   DOES NOT EXIST
#
# Setting contact_groups or contact_roles on a management_group budget is
# rejected by module validation rather than silently dropped.
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

module "consumption_budgets" {
  source = "../../"

  budgets = {
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
        warning = {
          threshold      = 50
          operator       = "GreaterThan"
          contact_emails = ["platform-owner@example.com", "finance@example.com"]
        }

        critical = {
          threshold      = 90
          operator       = "GreaterThan"
          contact_emails = ["platform-owner@example.com", "finance@example.com", "cto@example.com"]
        }

        # contact_groups / contact_roles are intentionally absent -- they do
        # not exist on this resource.
      }
    }
  }
}

output "budget_ids" {
  description = "Logical budget key -> Azure budget resource ID."
  value       = module.consumption_budgets.budget_ids
}
