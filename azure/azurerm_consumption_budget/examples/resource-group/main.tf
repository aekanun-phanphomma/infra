###############################################################################
# Example: multiple resource-group-scoped budgets in ONE subscription, created
# by ONE module invocation.
#
# Demonstrates:
#   * several resource groups, each with its own independent budget
#   * multiple notification thresholds per budget
#   * multiple email recipients per notification, differing per threshold
#   * contact_groups / contact_roles (supported at this scope)
#   * a filter with multiple dimensions and a tag
#
# Each budget below becomes its own resource instance:
#   azurerm_consumption_budget_resource_group.this["openai"]
#   azurerm_consumption_budget_resource_group.this["azure_foundry"]
#   azurerm_consumption_budget_resource_group.this["another_service"]
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
  # Built once so each budget below reads cleanly.
  rg_id_prefix = "/subscriptions/${var.subscription_guid}/resourceGroups"
}

module "consumption_budgets" {
  source = "../../"

  budgets = {
    #-------------------------------------------------------------------------
    # Multiple notifications, each with a different recipient list.
    #-------------------------------------------------------------------------
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
          operator       = "GreaterThan"
          contact_emails = ["owner@example.com", "devops@example.com"]
        }

        critical = {
          threshold      = 80
          operator       = "GreaterThan"
          contact_emails = ["owner@example.com", "devops@example.com", "finance@example.com"]
        }

        exceeded = {
          threshold      = 100
          operator       = "GreaterThanOrEqualTo"
          contact_emails = ["owner@example.com", "devops@example.com", "finance@example.com"]
          # Azure RBAC roles on the scope also get notified.
          contact_roles = ["Owner", "Contributor"]
        }

        # Forecast-based early warning, in addition to the actual-spend ones.
        forecast_overrun = {
          threshold      = 100
          operator       = "GreaterThan"
          threshold_type = "Forecasted"
          contact_emails = ["finance@example.com"]
        }
      }
    }

    #-------------------------------------------------------------------------
    # Same subscription, different resource group. Routes an alert through an
    # existing Action Group as well as email.
    #-------------------------------------------------------------------------
    azure_foundry = {
      scope_type        = "resource_group"
      resource_group_id = "${local.rg_id_prefix}/rg-azure-foundry"

      name       = "budget-azure-foundry"
      amount     = 2000
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
          contact_emails = ["owner@example.com", "finance@example.com"]
          # Action Group resource IDs. Not available at management group scope.
          contact_groups = var.action_group_ids
        }
      }
    }

    #-------------------------------------------------------------------------
    # Minimal budget: one notification, one recipient, plus a filter.
    #
    # NOTE: `notifications` can never be empty -- the provider declares the
    # notification block Required with MinItems: 1 on all three resources.
    #-------------------------------------------------------------------------
    another_service = {
      scope_type        = "resource_group"
      resource_group_id = "${local.rg_id_prefix}/rg-another-service"

      name       = "budget-another-service"
      amount     = 500
      time_grain = "Monthly"

      time_period = {
        start_date = var.budget_start_date
        end_date   = "2027-10-01T00:00:00Z"
      }

      notifications = {
        warning = {
          threshold      = 80
          contact_emails = ["owner@example.com"]
        }
      }

      # dimension and tag are sets on the provider side with no MaxItems, so
      # more than one of each is allowed.
      filter = {
        dimension = [
          {
            name   = "ResourceType"
            values = ["microsoft.compute/virtualmachines", "microsoft.storage/storageaccounts"]
          },
          {
            name   = "ResourceLocation"
            values = ["southeastasia"]
          },
        ]

        tag = [
          {
            name   = "costCenter"
            values = ["cc-1234"]
          },
        ]
      }
    }
  }
}

output "budget_ids" {
  description = "Logical budget key -> Azure budget resource ID."
  value       = module.consumption_budgets.budget_ids
}

output "budget_names" {
  description = "Logical budget key -> Azure budget name."
  value       = module.consumption_budgets.budget_names
}
