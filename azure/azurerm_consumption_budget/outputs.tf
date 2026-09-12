# Outputs are keyed by the caller's logical budget key, so callers never need
# to know which of the three resource types a budget became. The three source
# maps merge without collision because a key belongs to exactly one partition.

output "budget_ids" {
  description = "Map of logical budget key to Azure budget resource ID, across all scopes."

  value = merge(
    { for key, budget in azurerm_consumption_budget_subscription.this : key => budget.id },
    { for key, budget in azurerm_consumption_budget_resource_group.this : key => budget.id },
    { for key, budget in azurerm_consumption_budget_management_group.this : key => budget.id },
  )
}

output "budget_names" {
  description = "Map of logical budget key to the Azure budget name actually created."

  value = merge(
    { for key, budget in azurerm_consumption_budget_subscription.this : key => budget.name },
    { for key, budget in azurerm_consumption_budget_resource_group.this : key => budget.name },
    { for key, budget in azurerm_consumption_budget_management_group.this : key => budget.name },
  )
}

output "budget_ids_by_scope" {
  description = "Budget resource IDs grouped by scope type. All three keys are always present, each holding a possibly-empty map."

  value = {
    subscription     = { for key, budget in azurerm_consumption_budget_subscription.this : key => budget.id }
    resource_group   = { for key, budget in azurerm_consumption_budget_resource_group.this : key => budget.id }
    management_group = { for key, budget in azurerm_consumption_budget_management_group.this : key => budget.id }
  }
}

output "budget_scope_types" {
  description = "Map of logical budget key to the scope it was routed to, which determines the applicable terraform import command."
  value       = local.budget_scope_types
}

output "budget_etags" {
  description = "Map of logical budget key to the Azure-assigned ETag. Read-only: etag is a concurrency token, so it is not a module input."

  value = merge(
    { for key, budget in azurerm_consumption_budget_subscription.this : key => budget.etag },
    { for key, budget in azurerm_consumption_budget_resource_group.this : key => budget.etag },
    { for key, budget in azurerm_consumption_budget_management_group.this : key => budget.etag },
  )
}
