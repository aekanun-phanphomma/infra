###############################################################################
# Root variables — the opinionated, production-leaning surface. The modules can
# express far more; the root keeps the day-to-day knobs clean and readable.
###############################################################################

# ----------------------------------------------------------------------------
# Naming / location
# ----------------------------------------------------------------------------
variable "resource_group_name" {
  description = "Resource group that holds the AKS cluster and supporting resources."
  type        = string
  default     = "rg-aks-prod"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "southeastasia"
}

variable "cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
  default     = "aks-prod"
}

variable "kubernetes_version" {
  description = "Kubernetes minor version for the control plane (e.g. 1.30)."
  type        = string
  default     = "1.30"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    environment = "production"
    managed_by  = "terraform"
    workload    = "platform"
  }
}

# ----------------------------------------------------------------------------
# Networking (bring-your-own VNet)
# ----------------------------------------------------------------------------
variable "nodes_subnet_id" {
  description = "Subnet ID for the system node pool nodes."
  type        = string
}

variable "user_subnet_id" {
  description = "Subnet ID for the user (workload) node pool. Defaults to the system subnet when null."
  type        = string
  default     = null
}

variable "service_cidr" {
  description = "CIDR for Kubernetes service IPs (must not overlap the VNet)."
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "Cluster DNS service IP (must be inside service_cidr)."
  type        = string
  default     = "172.16.0.10"
}

variable "private_dns_zone_id" {
  description = "Private DNS zone for the API server. Use 'System' (AKS-managed), 'None', or a zone resource ID."
  type        = string
  default     = "System"
}

# ----------------------------------------------------------------------------
# System node pool sizing
# ----------------------------------------------------------------------------
variable "system_node_vm_size" {
  description = "VM size for the system node pool."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "system_node_min_count" {
  description = "Minimum nodes for the system pool autoscaler."
  type        = number
  default     = 3
}

variable "system_node_max_count" {
  description = "Maximum nodes for the system pool autoscaler."
  type        = number
  default     = 6
}

variable "system_node_zones" {
  description = "Availability zones for the system node pool."
  type        = list(string)
  default     = ["1", "2", "3"]
}

# ----------------------------------------------------------------------------
# User node pool sizing
# ----------------------------------------------------------------------------
variable "user_node_vm_size" {
  description = "VM size for the user (workload) node pool."
  type        = string
  default     = "Standard_D8s_v5"
}

variable "user_node_min_count" {
  description = "Minimum nodes for the user pool autoscaler."
  type        = number
  default     = 2
}

variable "user_node_max_count" {
  description = "Maximum nodes for the user pool autoscaler."
  type        = number
  default     = 20
}

variable "user_node_zones" {
  description = "Availability zones for the user node pool."
  type        = list(string)
  default     = ["1", "2", "3"]
}

# ----------------------------------------------------------------------------
# Identity / RBAC
# ----------------------------------------------------------------------------
variable "admin_group_object_ids" {
  description = "Entra ID group object IDs granted cluster-admin via AAD RBAC."
  type        = list(string)
  default     = []
}

# ----------------------------------------------------------------------------
# Observability
# ----------------------------------------------------------------------------
variable "create_log_analytics_workspace" {
  description = "Create a Log Analytics workspace for Container Insights. Set false to reuse an existing one."
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Existing Log Analytics workspace ID, used when create_log_analytics_workspace = false."
  type        = string
  default     = null
}

# ----------------------------------------------------------------------------
# Disk encryption (customer-managed keys)
# ----------------------------------------------------------------------------
variable "enable_disk_encryption_set" {
  description = "Create a Key Vault + key + Disk Encryption Set and wire it into the cluster for CMK disk encryption."
  type        = bool
  default     = true
}

variable "key_vault_purge_protection_enabled" {
  description = "Enable purge protection on the Key Vault (required for production CMK)."
  type        = bool
  default     = true
}

# ----------------------------------------------------------------------------
# Helm / platform add-ons (03-helm.tf)
# ----------------------------------------------------------------------------
variable "enable_helm_releases" {
  description = "Install the platform Helm releases (istio-base, istiod, external-dns). Disable on first apply if the runner cannot reach the private API server yet."
  type        = bool
  default     = true
}

variable "istio_version" {
  description = "Chart/app version for the Istio base + istiod releases."
  type        = string
  default     = "1.23.2"
}

variable "external_dns_version" {
  description = "Chart version for the external-dns release."
  type        = string
  default     = "1.15.0"
}

variable "external_dns_domain_filters" {
  description = "DNS zones external-dns is allowed to manage."
  type        = list(string)
  default     = []
}

variable "external_dns_azure_resource_group" {
  description = "Resource group containing the Azure DNS zone(s) external-dns manages."
  type        = string
  default     = null
}
