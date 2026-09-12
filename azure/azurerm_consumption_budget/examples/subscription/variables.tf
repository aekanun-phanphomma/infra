variable "subscription_guid" {
  description = "Azure subscription GUID (without the /subscriptions/ prefix) containing both resource groups."
  type        = string

  validation {
    condition     = can(regex("^(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_guid))
    error_message = "subscription_guid must be a bare GUID, e.g. \"00000000-0000-0000-0000-000000000000\"."
  }
}

variable "ai_resource_ids" {
  description = <<-DESC
    The four Azure OpenAI / Azure AI Foundry resource IDs the budget counts:
    two resource groups, one of each service in each.

    Paste the full resource ID of each account exactly as Azure reports it.
    Get them from the portal (resource -> Properties -> Resource ID) or:

      az resource list \
        --resource-type Microsoft.CognitiveServices/accounts \
        --query "[].id" -o tsv

    Pasting the real IDs rather than assembling them from parts also covers
    hub-based Azure AI Foundry, which is a
    Microsoft.MachineLearningServices/workspaces resource rather than a
    Microsoft.CognitiveServices/accounts one.

    Deliberately has no default: a placeholder ID would match nothing, and the
    budget would sit silently at zero while spend ran unchecked.
  DESC

  type = list(string)

  validation {
    condition     = length(var.ai_resource_ids) > 0
    error_message = "Provide at least one resource ID, otherwise the filter matches nothing and the budget never triggers."
  }

  validation {
    condition     = alltrue([for id in var.ai_resource_ids : length(trimspace(id)) > 0])
    error_message = "Resource IDs must not be empty or whitespace."
  }

  validation {
    condition     = length(distinct(var.ai_resource_ids)) == length(var.ai_resource_ids)
    error_message = "Resource IDs must be unique; the same account is listed more than once."
  }
}

variable "budget_amount" {
  description = "Budget amount in the subscription billing currency. The notification fires above this figure."
  type        = number
  default     = 100
}

variable "budget_contact_emails" {
  description = "Email recipients for the budget alert. Two people per the requirement."
  type        = list(string)

  default = [
    "owner@example.com",
    "finance@example.com",
  ]

  validation {
    condition     = length(var.budget_contact_emails) > 0
    error_message = "At least one recipient is required, otherwise the notification would have nobody to alert."
  }
}

variable "budget_start_date" {
  description = "RFC3339 budget start date. Must be the first day of a month, on or after 2017-06-01."
  type        = string
  default     = "2026-10-01T00:00:00Z"
}
