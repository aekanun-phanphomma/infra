###############################################################################
# Unit tests for the aks-nodepool module in isolation.
###############################################################################

mock_provider "azurerm" {}

variables {
  kubernetes_cluster_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.ContainerService/managedClusters/aks-test"
  name                  = "user"
  vm_size               = "Standard_D8s_v5"
}

run "managed_pool_when_ignoring_node_count" {
  command = plan

  module {
    source = "./modules/aks-nodepool"
  }

  variables {
    ignore_node_count_changes = true
  }

  assert {
    condition     = length(azurerm_kubernetes_cluster_node_pool.managed) == 1 && length(azurerm_kubernetes_cluster_node_pool.fixed) == 0
    error_message = "When ignoring node_count drift, only the managed pool variant should be planned."
  }
}

run "fixed_pool_when_not_ignoring_node_count" {
  command = plan

  module {
    source = "./modules/aks-nodepool"
  }

  variables {
    ignore_node_count_changes = false
  }

  assert {
    condition     = length(azurerm_kubernetes_cluster_node_pool.fixed) == 1 && length(azurerm_kubernetes_cluster_node_pool.managed) == 0
    error_message = "When Terraform owns node_count, only the fixed pool variant should be planned."
  }
}

run "rejects_invalid_mode" {
  command = plan

  module {
    source = "./modules/aks-nodepool"
  }

  variables {
    mode = "Invalid"
  }

  expect_failures = [
    var.mode,
  ]
}
