output "root_management_group_id" {
  description = "Resource ID of the root management group."
  value       = azurerm_management_group.root.id
}

output "platform_management_group_id" {
  description = "Resource ID of the Platform management group."
  value       = azurerm_management_group.platform.id
}

output "workloads_management_group_id" {
  description = "Resource ID of the Workloads management group."
  value       = azurerm_management_group.workloads.id
}

output "sandbox_management_group_id" {
  description = "Resource ID of the Sandbox management group."
  value       = azurerm_management_group.sandbox.id
}
