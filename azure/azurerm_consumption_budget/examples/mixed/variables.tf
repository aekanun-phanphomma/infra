variable "subscription_guid" {
  description = "Azure subscription GUID that hosts the subscription budget and both resource groups."
  type        = string

  validation {
    condition     = can(regex("^(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_guid))
    error_message = "subscription_guid must be a bare GUID, e.g. \"00000000-0000-0000-0000-000000000000\"."
  }
}

variable "management_group_name" {
  description = "Management group name (the last segment of the management group resource ID), not the display name."
  type        = string
}

variable "budget_start_date" {
  description = "RFC3339 budget start date applied to all four budgets. Must be the first day of a month, on or after 2017-06-01."
  type        = string
  default     = "2026-10-01T00:00:00Z"
}
