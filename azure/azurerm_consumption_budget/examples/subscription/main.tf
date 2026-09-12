###############################################################################
# Example: one $100 budget covering Azure OpenAI + Azure AI Foundry across two
# resource groups in the same subscription, alerting two people by email.
#
#   subscription
#     |
#     +-- rg-ai-one ---- Azure OpenAI account      \
#     |                  Azure AI Foundry account   |  4 resource IDs,
#     +-- rg-ai-two ---- Azure OpenAI account       |  ONE $100 budget
#                        Azure AI Foundry account  /
#
# The budget is SUBSCRIPTION-scoped so a single $100 limit spans both resource
# groups, then narrowed with a `ResourceId` filter to exactly those four
# accounts. Anything else in the subscription is ignored.
#
# Why subscription scope rather than two resource group budgets: a resource
# group budget cannot span two resource groups, so two of them would mean two
# independent $100 limits ($200 of exposure). One filtered subscription budget
# gives a single shared $100 ceiling.
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
    ai_platform = {
      scope_type      = "subscription"
      subscription_id = "/subscriptions/${var.subscription_guid}"

      name       = "budget-ai-platform"
      amount     = var.budget_amount
      time_grain = "Monthly"

      time_period = {
        start_date = var.budget_start_date
      }

      # Alert once actual spend across the four accounts passes the amount.
      # threshold is a PERCENTAGE of `amount`, so 100 means "100% of $100".
      notifications = {
        exceeded = {
          threshold      = 100
          operator       = "GreaterThan"
          threshold_type = "Actual"
          contact_emails = var.budget_contact_emails
        }
      }

      # Count only the four AI accounts. `ResourceId` is one of the 24
      # dimensions Azure supports, and the values are your own resource IDs --
      # no billing meter names to guess at.
      filter = {
        dimension = [
          {
            name   = "ResourceId"
            values = var.ai_resource_ids
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

output "filtered_resource_ids" {
  description = "The resource IDs this budget counts. Compare these against Cost analysis grouped by Resource to confirm the filter matches."
  value       = var.ai_resource_ids
}
