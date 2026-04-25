# azure/vm

Deploys a single Ubuntu 22.04 LTS Linux virtual machine on Azure with:
- System-assigned managed identity
- Premium SSD OS disk
- SSH key authentication (password auth disabled)
- Dynamic private IP via a dedicated NIC

## Usage

```hcl
module "vm" {
  source = "./infra/azure/vm"

  resource_group_name  = "rg-myapp-prod"
  location             = "eastus"
  vm_name              = "vm-myapp-01"
  vm_size              = "Standard_D2s_v5"
  admin_username       = "azureuser"
  admin_ssh_public_key = file("~/.ssh/id_rsa.pub")
  subnet_id            = "/subscriptions/.../subnets/default"
  os_disk_size_gb      = 128

  tags = {
    environment = "production"
    team        = "platform"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| resource_group_name | string | `"rg-vm"` | Name of the Azure Resource Group to create. |
| location | string | `"eastus"` | Azure region where resources will be deployed. |
| vm_name | string | `"vm-linux-01"` | Name of the Linux virtual machine. |
| vm_size | string | `"Standard_D2s_v5"` | Azure VM size/SKU. |
| admin_username | string | `"azureuser"` | Admin username for the virtual machine. |
| admin_ssh_public_key | string | *(required)* | SSH public key for admin user authentication. |
| subnet_id | string | *(required)* | Subnet resource ID to attach the NIC. |
| os_disk_size_gb | number | `128` | OS disk size in GB. |
| tags | map(string) | `{}` | Map of tags to apply to all resources. |

## Outputs

| Name | Description |
|------|-------------|
| vm_id | Resource ID of the Linux virtual machine. |
| vm_private_ip | Private IP address assigned to the VM NIC. |
| vm_identity_principal_id | Principal ID of the system-assigned managed identity. |
