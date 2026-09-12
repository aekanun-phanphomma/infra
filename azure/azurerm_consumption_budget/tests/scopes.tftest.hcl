###############################################################################
# tests/scopes.tftest.hcl
#
# Scope routing and Terraform address stability.
# Matrix coverage: Test 1, 2, 3, 4, 9, 16.
#
# All runs use `command = plan` -- nothing is created in Azure. They do,
# however, require the azurerm provider to configure successfully, which means
# valid Azure credentials must be present. See tests/README.md.
#
# Scope IDs are written out in full rather than composed from helper variables:
# a Terraform test file can only set variables the module under test actually
# declares, and it has no `locals` block of its own.
###############################################################################

provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

#--- Test 1: one subscription budget ----------------------------------------
run "test01_single_subscription_budget" {
  command = plan

  variables {
    budgets = {
      platform = {
        scope_type      = "subscription"
        subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
        amount          = 5000
        time_period     = { start_date = "2026-10-01T00:00:00Z" }
        notifications = {
          warning = { threshold = 80, contact_emails = ["owner@example.com"] }
        }
      }
    }
  }

  assert {
    condition     = output.budget_scope_types["platform"] == "subscription"
    error_message = "platform should route to the subscription scope"
  }

  assert {
    condition     = length(azurerm_consumption_budget_subscription.this) == 1
    error_message = "expected exactly one subscription budget resource"
  }

  assert {
    condition = (
      length(azurerm_consumption_budget_resource_group.this) == 0 &&
      length(azurerm_consumption_budget_management_group.this) == 0
    )
    error_message = "no resource group or management group budgets should be created"
  }

  # `name` was omitted, so it must fall back to the logical map key.
  assert {
    condition     = azurerm_consumption_budget_subscription.this["platform"].name == "platform"
    error_message = "budget name should default to the logical map key"
  }

  # Module default for an argument the provider declares Required with no default.
  assert {
    condition = alltrue([
      for n in azurerm_consumption_budget_subscription.this["platform"].notification :
      n.operator == "GreaterThan" && n.threshold_type == "Actual" && n.enabled
    ])
    error_message = "notification defaults should be operator=GreaterThan, threshold_type=Actual, enabled=true"
  }
}

#--- Test 2: one resource group budget --------------------------------------
run "test02_single_resource_group_budget" {
  command = plan

  variables {
    budgets = {
      openai = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        name              = "budget-openai"
        amount            = 1000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications = {
          warning = { threshold = 80, contact_emails = ["owner@example.com"] }
        }
      }
    }
  }

  assert {
    condition     = length(azurerm_consumption_budget_resource_group.this) == 1
    error_message = "expected exactly one resource group budget resource"
  }

  assert {
    condition     = azurerm_consumption_budget_resource_group.this["openai"].name == "budget-openai"
    error_message = "an explicit name should win over the map key"
  }
}

#--- Test 3: one management group budget ------------------------------------
run "test03_single_management_group_budget" {
  command = plan

  variables {
    budgets = {
      enterprise = {
        scope_type          = "management_group"
        management_group_id = "/providers/Microsoft.Management/managementGroups/mg-root"
        amount              = 50000
        time_period         = { start_date = "2026-10-01T00:00:00Z" }
        notifications = {
          warning = { threshold = 75, contact_emails = ["finance@example.com"] }
        }
      }
    }
  }

  assert {
    condition     = length(azurerm_consumption_budget_management_group.this) == 1
    error_message = "expected exactly one management group budget resource"
  }

  assert {
    condition     = output.budget_scope_types["enterprise"] == "management_group"
    error_message = "enterprise should route to the management group scope"
  }
}

#--- Test 4: several resource group budgets in the SAME subscription --------
run "test04_multiple_resource_groups_same_subscription" {
  command = plan

  variables {
    budgets = {
      openai = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        amount            = 1000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { warning = { threshold = 80, contact_emails = ["a@example.com"] } }
      }
      azure_foundry = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-azure-foundry"
        amount            = 2000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { warning = { threshold = 80, contact_emails = ["a@example.com"] } }
      }
      another_service = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-another-service"
        amount            = 500
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { warning = { threshold = 80, contact_emails = ["a@example.com"] } }
      }
    }
  }

  assert {
    condition     = length(azurerm_consumption_budget_resource_group.this) == 3
    error_message = "three independent resource group budgets should be created"
  }

  # Each instance must carry its own resource group ID -- no bleed between them.
  assert {
    condition = alltrue([
      azurerm_consumption_budget_resource_group.this["openai"].resource_group_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai",
      azurerm_consumption_budget_resource_group.this["azure_foundry"].resource_group_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-azure-foundry",
      azurerm_consumption_budget_resource_group.this["another_service"].resource_group_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-another-service",
    ])
    error_message = "each budget must target its own resource group"
  }

  assert {
    condition     = azurerm_consumption_budget_resource_group.this["another_service"].amount == 500
    error_message = "each budget must keep its own amount"
  }
}

#--- Test 9: mixed scopes in one invocation ---------------------------------
run "test09_mixed_scopes" {
  command = plan

  variables {
    budgets = {
      platform = {
        scope_type      = "subscription"
        subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
        amount          = 5000
        time_period     = { start_date = "2026-10-01T00:00:00Z" }
        notifications   = { warning = { threshold = 50, contact_emails = ["a@example.com"] } }
      }
      openai = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        amount            = 1000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { warning = { threshold = 50, contact_emails = ["a@example.com"] } }
      }
      azure_foundry = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-azure-foundry"
        amount            = 2000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { warning = { threshold = 50, contact_emails = ["a@example.com"] } }
      }
      enterprise = {
        scope_type          = "management_group"
        management_group_id = "/providers/Microsoft.Management/managementGroups/mg-root"
        amount              = 50000
        time_period         = { start_date = "2026-10-01T00:00:00Z" }
        notifications       = { warning = { threshold = 50, contact_emails = ["a@example.com"] } }
      }
    }
  }

  assert {
    condition = (
      length(azurerm_consumption_budget_subscription.this) == 1 &&
      length(azurerm_consumption_budget_resource_group.this) == 2 &&
      length(azurerm_consumption_budget_management_group.this) == 1
    )
    error_message = "one subscription, two resource group and one management group budget expected"
  }

  assert {
    condition     = length(keys(output.budget_ids_by_scope["resource_group"])) == 2
    error_message = "budget_ids_by_scope should group the two resource group budgets together"
  }

  assert {
    condition = alltrue([
      output.budget_scope_types["platform"] == "subscription",
      output.budget_scope_types["openai"] == "resource_group",
      output.budget_scope_types["azure_foundry"] == "resource_group",
      output.budget_scope_types["enterprise"] == "management_group",
    ])
    error_message = "every budget should report the scope it was routed to"
  }
}

#--- Test 16: map ordering must not change resource addresses ---------------
# The same three budgets as test04, written in a different source order.
# Because `budgets` is a map and for_each keys off the logical key (never an
# index), the resource addresses are identical -- there is no [0]/[1]/[2] to
# shuffle, so no spurious replacement.
run "test16_reordering_does_not_change_addresses" {
  command = plan

  variables {
    budgets = {
      another_service = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-another-service"
        amount            = 500
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { warning = { threshold = 80, contact_emails = ["a@example.com"] } }
      }
      azure_foundry = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-azure-foundry"
        amount            = 2000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { warning = { threshold = 80, contact_emails = ["a@example.com"] } }
      }
      openai = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        amount            = 1000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { warning = { threshold = 80, contact_emails = ["a@example.com"] } }
      }
    }
  }

  # Identical key set to test04 despite the different written order.
  assert {
    condition = sort(keys(azurerm_consumption_budget_resource_group.this)) == tolist([
      "another_service", "azure_foundry", "openai",
    ])
    error_message = "resource instance keys must be the logical budget keys, independent of source ordering"
  }

  # Values must still be bound to the right key after reordering.
  assert {
    condition = (
      azurerm_consumption_budget_resource_group.this["openai"].amount == 1000 &&
      azurerm_consumption_budget_resource_group.this["another_service"].amount == 500
    )
    error_message = "reordering must not rebind a budget key to another budget's values"
  }
}
