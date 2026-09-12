variable "subscription_guid" {
  description = "Azure subscription GUID (without the /subscriptions/ prefix) that the budget is scoped to."
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

variable "budget_contact_emails" {
  description = "Email recipients for the budget notification."
  type        = list(string)
  default     = ["owner@example.com"]
}
