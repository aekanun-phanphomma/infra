locals {
  # One partition per scope. Each budget lands in exactly one; invalid
  # scope_type values are rejected by variable validation before this runs.
  subscription_budgets = {
    for key, budget in var.budgets : key => budget
    if budget.scope_type == "subscription"
  }

  resource_group_budgets = {
    for key, budget in var.budgets : key => budget
    if budget.scope_type == "resource_group"
  }

  management_group_budgets = {
    for key, budget in var.budgets : key => budget
    if budget.scope_type == "management_group"
  }

  # `name` is optional; resolving the fallback once keeps the three resource
  # files and the outputs consistent.
  budget_names = {
    for key, budget in var.budgets : key => coalesce(budget.name, key)
  }

  budget_scope_types = {
    for key, budget in var.budgets : key => budget.scope_type
  }
}
