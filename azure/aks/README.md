# azure/aks

Deploys a private Azure Kubernetes Service (AKS) cluster with:
- System-assigned managed identity
- Azure CNI networking with Azure network policy
- Azure AD RBAC integration (managed)
- Autoscaling system node pool
- OMS agent add-on for Azure Monitor integration
- User-defined routing (UDR) outbound type for egress control

## Usage

```hcl
module "aks" {
  source = "./infra/azure/aks"

  resource_group_name        = "rg-aks-prod"
  location                   = "eastus"
  cluster_name               = "aks-prod"
  kubernetes_version         = "1.29"
  nodes_subnet_id            = "/subscriptions/.../subnets/aks-nodes"
  system_node_vm_size        = "Standard_D4s_v5"
  system_node_count          = 3
  system_node_min_count      = 2
  system_node_max_count      = 10
  service_cidr               = "172.16.0.0/16"
  dns_service_ip             = "172.16.0.10"
  log_analytics_workspace_id = "/subscriptions/.../workspaces/law-prod"

  tags = {
    environment = "production"
    team        = "platform"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| resource_group_name | string | `"rg-aks"` | Name of the Azure Resource Group to create. |
| location | string | `"eastus"` | Azure region where resources will be deployed. |
| cluster_name | string | `"aks-prod"` | Name of the AKS cluster. |
| kubernetes_version | string | `"1.29"` | Kubernetes version for the AKS cluster. |
| nodes_subnet_id | string | *(required)* | Subnet ID for AKS node pools. |
| system_node_vm_size | string | `"Standard_D4s_v5"` | VM size for system node pool nodes. |
| system_node_count | number | `3` | Initial node count for the system node pool. |
| system_node_min_count | number | `2` | Minimum node count for autoscaling. |
| system_node_max_count | number | `10` | Maximum node count for autoscaling. |
| service_cidr | string | `"172.16.0.0/16"` | CIDR block for Kubernetes services. |
| dns_service_ip | string | `"172.16.0.10"` | IP address for the Kubernetes DNS service (must be within service_cidr). |
| log_analytics_workspace_id | string | *(required)* | Log Analytics Workspace ID for the OMS agent add-on. |
| tags | map(string) | `{}` | Map of tags to apply to all resources. |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | Resource ID of the AKS cluster. |
| cluster_fqdn | FQDN of the AKS cluster API server. |
| kube_config_raw | Raw kubeconfig for the AKS cluster (sensitive). |
| kubelet_identity_object_id | Object ID of the kubelet managed identity. |
| cluster_identity_principal_id | Principal ID of the cluster system-assigned managed identity. |
