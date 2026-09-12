variable "subscription_guid" {
  description = "Azure subscription GUID containing all three resource groups."
  type        = string

  validation {
    condition     = can(regex("^(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_guid))
    error_message = "subscription_guid must be a bare GUID, e.g. \"00000000-0000-0000-0000-000000000000\"."
  }
}

variable "budget_start_date" {
  description = "RFC3339 budget start date. Must be the first day of a month, on or after 2017-06-01."
  type        = string
  default     = "2026-10-01T00:00:00Z"
}

variable "action_group_ids" {
  description = <<-DESC
    Azure Action Group resource IDs to notify, e.g.
    "/subscriptions/<guid>/resourceGroups/<rg>/providers/microsoft.insights/actionGroups/<name>".

    Only valid for subscription and resource group budgets -- the management
    group resource has no contact_groups argument.
  DESC
  type        = list(string)
  default     = []
}
