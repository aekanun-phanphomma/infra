variable "resource_group_name" {
  description = "Name of the Azure Resource Group to create."
  type        = string
  default     = "rg-vm"
}

variable "location" {
  description = "Azure region where resources will be deployed."
  type        = string
  default     = "eastus"
}

variable "vm_name" {
  description = "Name of the Linux virtual machine."
  type        = string
  default     = "vm-linux-01"
}

variable "vm_size" {
  description = "Azure VM size/SKU."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "admin_username" {
  description = "Admin username for the virtual machine."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for admin user authentication."
  type        = string
  sensitive   = true
}

variable "subnet_id" {
  description = "Subnet resource ID to attach the NIC."
  type        = string
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB."
  type        = number
  default     = 128
}

variable "tags" {
  description = "Map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}
