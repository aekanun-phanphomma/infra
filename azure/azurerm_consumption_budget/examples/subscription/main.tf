###############################################################################
# Example: a single subscription-scoped consumption budget.
#
# This is the root module, so THIS is where the provider is configured -- the
# reusable module deliberately contains no provider block.
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

  # azurerm 4.x requires an explicit subscription for the provider itself.
  # Supplied by the caller (variable / ARM_SUBSCRIPTION_ID), never hardcoded.
  subscription_id = var.subscription_guid
}

module "consumption_budgets" {
  source = "../../"

  budgets = {
    platform = {
      scope_type = "subscription"

      # Full resource ID form. azurerm 4.x validates with
      # commonids.ValidateSubscriptionID, so a bare GUID is rejected.
      subscription_id = "/subscriptions/${var.subscription_guid}"

      name       = "budget-platform"
      amount     = 5000
      time_grain = "Monthly"

      # Required by the provider: MinItems 1, MaxItems 1.
      # start_date must be the first of a month, RFC3339, >= 2017-06-01.
      time_period = {
        start_date = var.budget_start_date
      }

      # Map keys ("warning") are Terraform-side labels only; they are never
      # sent to Azure. They exist so that adding "critical" later does not
      # churn the existing notification.
      notifications = {
        warning = {
          threshold      = 80
          operator       = "GreaterThan"
          threshold_type = "Actual"
          contact_emails = var.budget_contact_emails
        }
      }
    }
  }
}

output "budget_ids" {
  description = "Logical budget key -> Azure budget resource ID."
  value       = module.consumption_budgets.budget_ids
}
