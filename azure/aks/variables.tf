variable "resource_group_name" {
  description = "Name of the Azure Resource Group to create."
  type        = string
  default     = "rg-aks"
}

variable "location" {
  description = "Azure region where resources will be deployed."
  type        = string
  default     = "eastus"
}

variable "cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
  default     = "aks-prod"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster."
  type        = string
  default     = "1.29"
}

variable "nodes_subnet_id" {
  description = "Subnet ID for AKS node pools."
  type        = string
}

variable "system_node_vm_size" {
  description = "VM size for system node pool nodes."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "system_node_count" {
  description = "Initial node count for the system node pool."
  type        = number
  default     = 3
}

variable "system_node_min_count" {
  description = "Minimum node count for autoscaling."
  type        = number
  default     = 2
}

variable "system_node_max_count" {
  description = "Maximum node count for autoscaling."
  type        = number
  default     = 10
}

variable "service_cidr" {
  description = "CIDR block for Kubernetes services."
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for the Kubernetes DNS service (must be within service_cidr)."
  type        = string
  default     = "172.16.0.10"
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for the OMS agent add-on."
  type        = string
}

variable "tags" {
  description = "Map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}
