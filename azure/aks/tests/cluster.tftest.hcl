###############################################################################
# Native Terraform tests (terraform test). Providers are mocked so the suite
# runs offline with no Azure credentials. Focus: the configuration plans cleanly
# and the security-relevant settings are wired as intended.
###############################################################################

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      object_id       = "00000000-0000-0000-0000-000000000001"
      client_id       = "00000000-0000-0000-0000-000000000002"
      subscription_id = "00000000-0000-0000-0000-000000000003"
    }
  }
}
mock_provider "azuread" {}
mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  resource_group_name    = "rg-aks-test"
  location               = "southeastasia"
  cluster_name           = "aks-test"
  kubernetes_version     = "1.30"
  nodes_subnet_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/system"
  enable_helm_releases   = false
  admin_group_object_ids = ["11111111-1111-1111-1111-111111111111"]
}

run "plan_is_clean" {
  command = plan
}

run "control_plane_identity_is_created" {
  command = plan

  assert {
    condition     = azurerm_user_assigned_identity.cluster.name == "id-aks-test"
    error_message = "A user-assigned identity should be created for the control plane."
  }
}

run "disk_encryption_set_created_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_disk_encryption_set.this) == 1
    error_message = "Disk Encryption Set should be created when enable_disk_encryption_set is true (default)."
  }
}

run "disk_encryption_can_be_disabled" {
  command = plan

  variables {
    enable_disk_encryption_set = false
  }

  assert {
    condition     = length(azurerm_disk_encryption_set.this) == 0
    error_message = "Disk Encryption Set must not be created when disabled."
  }
}

run "reuse_existing_log_analytics_workspace" {
  command = plan

  variables {
    create_log_analytics_workspace = false
    log_analytics_workspace_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/existing"
  }

  assert {
    condition     = length(azurerm_log_analytics_workspace.this) == 0
    error_message = "Workspace must not be created when reusing an existing one."
  }
}
