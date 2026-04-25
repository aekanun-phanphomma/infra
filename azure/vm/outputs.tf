output "vm_id" {
  description = "Resource ID of the Linux virtual machine."
  value       = azurerm_linux_virtual_machine.vm.id
}

output "vm_private_ip" {
  description = "Private IP address assigned to the VM NIC."
  value       = azurerm_network_interface.vm.private_ip_address
}

output "vm_identity_principal_id" {
  description = "Principal ID of the system-assigned managed identity."
  value       = azurerm_linux_virtual_machine.vm.identity[0].principal_id
}
