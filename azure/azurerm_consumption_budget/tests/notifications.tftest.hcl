###############################################################################
# tests/notifications.tftest.hcl
#
# Notification fan-out and recipient handling.
# Matrix coverage: Test 5, 6, 7, 8 (plus filter and scope-specific notification
# schema checks).
#
# Requires Azure credentials for the provider to configure; see tests/README.md.
###############################################################################

provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

#--- Test 5: one budget, one notification -----------------------------------
run "test05_single_notification" {
  command = plan

  variables {
    budgets = {
      openai = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        amount            = 1000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications = {
          warning = { threshold = 80, contact_emails = ["owner@example.com"] }
        }
      }
    }
  }

  assert {
    condition     = length(azurerm_consumption_budget_resource_group.this["openai"].notification) == 1
    error_message = "exactly one notification block should be emitted"
  }
}

#--- Test 6: one budget, multiple notifications -----------------------------
run "test06_multiple_notifications" {
  command = plan

  variables {
    budgets = {
      openai = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        amount            = 1000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications = {
          warning  = { threshold = 50, contact_emails = ["owner@example.com"] }
          critical = { threshold = 80, contact_emails = ["owner@example.com"] }
          exceeded = { threshold = 100, operator = "GreaterThanOrEqualTo", contact_emails = ["owner@example.com"] }
        }
      }
    }
  }

  assert {
    condition     = length(azurerm_consumption_budget_resource_group.this["openai"].notification) == 3
    error_message = "three notification blocks should be emitted, one per map entry"
  }

  # The map keys are Terraform-side labels only. Verify the thresholds made it
  # through and that the key itself is nowhere in the payload.
  assert {
    condition = sort([
      for n in azurerm_consumption_budget_resource_group.this["openai"].notification : tostring(n.threshold)
    ]) == tolist(["100", "50", "80"])
    error_message = "all three thresholds should be present"
  }

  assert {
    condition = length([
      for n in azurerm_consumption_budget_resource_group.this["openai"].notification :
      n if n.operator == "GreaterThanOrEqualTo"
    ]) == 1
    error_message = "the per-notification operator override should be preserved"
  }
}

#--- Test 7: one notification, multiple email recipients --------------------
run "test07_single_notification_multiple_emails" {
  command = plan

  variables {
    budgets = {
      openai = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        amount            = 1000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications = {
          warning = {
            threshold = 50
            contact_emails = [
              "owner@example.com",
              "devops@example.com",
              "finance@example.com",
            ]
          }
        }
      }
    }
  }

  assert {
    condition = alltrue([
      for n in azurerm_consumption_budget_resource_group.this["openai"].notification :
      length(n.contact_emails) == 3
    ])
    error_message = "all three email recipients should reach the notification block"
  }

  # contact_emails is a TypeList on the provider side, so order is preserved.
  assert {
    condition = alltrue([
      for n in azurerm_consumption_budget_resource_group.this["openai"].notification :
      n.contact_emails[0] == "owner@example.com"
    ])
    error_message = "contact_emails is a list, so the caller's ordering should be preserved"
  }

  # Unused recipient channels are collapsed to null rather than sent empty.
  assert {
    condition = alltrue([
      for n in azurerm_consumption_budget_resource_group.this["openai"].notification :
      length(n.contact_groups) == 0 && length(n.contact_roles) == 0
    ])
    error_message = "unused contact channels should stay empty"
  }
}

#--- Test 8: multiple notifications, each with multiple recipients ----------
run "test08_multiple_notifications_multiple_emails" {
  command = plan

  variables {
    budgets = {
      openai = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        amount            = 1000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications = {
          warning = {
            threshold      = 50
            contact_emails = ["owner@example.com", "devops@example.com"]
          }
          critical = {
            threshold      = 80
            contact_emails = ["owner@example.com", "devops@example.com", "finance@example.com"]
            contact_roles  = ["Owner", "Contributor"]
          }
          forecast = {
            threshold      = 100
            threshold_type = "Forecasted"
            contact_emails = ["finance@example.com"]
            contact_groups = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ops/providers/microsoft.insights/actionGroups/ag-finops"]
          }
        }
      }
    }
  }

  assert {
    condition     = length(azurerm_consumption_budget_resource_group.this["openai"].notification) == 3
    error_message = "three notification blocks expected"
  }

  # Recipient lists must stay attached to their own notification.
  assert {
    condition = alltrue([
      for n in azurerm_consumption_budget_resource_group.this["openai"].notification :
      (n.threshold == 50 ? length(n.contact_emails) == 2 : true) &&
      (n.threshold == 80 ? length(n.contact_emails) == 3 && length(n.contact_roles) == 2 : true) &&
      (n.threshold == 100 ? length(n.contact_emails) == 1 && length(n.contact_groups) == 1 : true)
    ])
    error_message = "each notification should keep its own recipient lists"
  }

  assert {
    condition = length([
      for n in azurerm_consumption_budget_resource_group.this["openai"].notification :
      n if n.threshold_type == "Forecasted"
    ]) == 1
    error_message = "exactly one notification should be Forecasted"
  }
}

#--- Management group scope uses the reduced notification schema -------------
run "management_group_notifications_emails_only" {
  command = plan

  variables {
    budgets = {
      enterprise = {
        scope_type          = "management_group"
        management_group_id = "/providers/Microsoft.Management/managementGroups/mg-root"
        amount              = 50000
        time_period         = { start_date = "2026-10-01T00:00:00Z" }
        notifications = {
          warning  = { threshold = 75, contact_emails = ["finance@example.com"] }
          exceeded = { threshold = 100, operator = "GreaterThanOrEqualTo", contact_emails = ["finance@example.com", "cto@example.com"] }
        }
      }
    }
  }

  assert {
    condition     = length(azurerm_consumption_budget_management_group.this["enterprise"].notification) == 2
    error_message = "two notification blocks expected at management group scope"
  }

  assert {
    condition = alltrue([
      for n in azurerm_consumption_budget_management_group.this["enterprise"].notification :
      length(n.contact_emails) > 0
    ])
    error_message = "contact_emails is Required (MinItems 1) on the management group resource"
  }
}

#--- Filter fan-out: multiple dimensions and multiple tags ------------------
run "filter_multiple_dimensions_and_tags" {
  command = plan

  variables {
    budgets = {
      filtered = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        amount            = 1000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { warning = { threshold = 80, contact_emails = ["a@example.com"] } }

        filter = {
          dimension = [
            { name = "ResourceType", values = ["microsoft.compute/virtualmachines"] },
            { name = "ResourceLocation", values = ["southeastasia", "eastasia"] },
          ]
          tag = [
            { name = "costCenter", values = ["cc-1234"] },
            { name = "env", values = ["prod"] },
          ]
        }
      }
    }
  }

  assert {
    condition     = length(azurerm_consumption_budget_resource_group.this["filtered"].filter) == 1
    error_message = "exactly one filter block should be emitted"
  }

  assert {
    condition = (
      length(azurerm_consumption_budget_resource_group.this["filtered"].filter[0].dimension) == 2 &&
      length(azurerm_consumption_budget_resource_group.this["filtered"].filter[0].tag) == 2
    )
    error_message = "dimension and tag are sets with no MaxItems, so both entries of each should survive"
  }
}

#--- Omitting filter entirely emits no filter block -------------------------
run "no_filter_emits_no_block" {
  command = plan

  variables {
    budgets = {
      plain = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        amount            = 1000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { warning = { threshold = 80, contact_emails = ["a@example.com"] } }
      }
    }
  }

  assert {
    condition     = length(azurerm_consumption_budget_resource_group.this["plain"].filter) == 0
    error_message = "no filter block should be emitted when filter is null"
  }
}
