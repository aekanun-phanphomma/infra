terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  # backend "azurerm" { ... }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "aks" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                    = var.cluster_name
  resource_group_name     = azurerm_resource_group.aks.name
  location                = azurerm_resource_group.aks.location
  dns_prefix              = var.cluster_name
  kubernetes_version      = var.kubernetes_version
  private_cluster_enabled = true
  node_resource_group     = "${var.resource_group_name}-nodes"
  tags                    = var.tags

  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.system_node_vm_size
    vnet_subnet_id      = var.nodes_subnet_id
    type                = "VirtualMachineScaleSets"
    os_disk_type        = "Managed"
    os_disk_size_gb     = 128
    max_pods            = 110
    enable_auto_scaling = true
    min_count           = var.system_node_min_count
    max_count           = var.system_node_max_count

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "userDefinedRouting"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
  }

  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }
}
