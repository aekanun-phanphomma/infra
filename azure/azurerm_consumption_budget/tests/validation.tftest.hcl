###############################################################################
# tests/validation.tftest.hcl
#
# Rejection cases: each must fail module variable validation rather than
# reaching Azure. Matrix coverage: Tests 10-15.
#
# The last run is the mirror image: inputs the module must NOT reject, guarding
# against the validation rules becoming over-strict.
#
# `terraform test` configures providers before any run, so these need Azure
# credentials. The same rules run credential-free via
# tests/run_validation_tests.sh.
###############################################################################

provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

#--- Test 11: invalid scope_type --------------------------------------------
run "test11_invalid_scope_type" {
  command = plan

  variables {
    budgets = {
      bad = {
        scope_type      = "rg"
        subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
        amount          = 100
        time_period     = { start_date = "2026-10-01T00:00:00Z" }
        notifications   = { w = { threshold = 50, contact_emails = ["a@example.com"] } }
      }
    }
  }

  expect_failures = [var.budgets]
}

#--- Test 12: resource_group scope without resource_group_id ----------------
run "test12_resource_group_scope_missing_id" {
  command = plan

  variables {
    budgets = {
      openai = {
        scope_type    = "resource_group"
        amount        = 1000
        time_period   = { start_date = "2026-10-01T00:00:00Z" }
        notifications = { w = { threshold = 50, contact_emails = ["a@example.com"] } }
      }
    }
  }

  expect_failures = [var.budgets]
}

#--- Test 13: subscription scope without subscription_id --------------------
run "test13_subscription_scope_missing_id" {
  command = plan

  variables {
    budgets = {
      platform = {
        scope_type    = "subscription"
        amount        = 5000
        time_period   = { start_date = "2026-10-01T00:00:00Z" }
        notifications = { w = { threshold = 50, contact_emails = ["a@example.com"] } }
      }
    }
  }

  expect_failures = [var.budgets]
}

#--- Test 13b: subscription scope carrying only a management_group_id -------
run "test13b_subscription_scope_with_wrong_id" {
  command = plan

  variables {
    budgets = {
      platform = {
        scope_type          = "subscription"
        management_group_id = "/providers/Microsoft.Management/managementGroups/mg-root"
        amount              = 5000
        time_period         = { start_date = "2026-10-01T00:00:00Z" }
        notifications       = { w = { threshold = 50, contact_emails = ["a@example.com"] } }
      }
    }
  }

  expect_failures = [var.budgets]
}

#--- Test 14: management_group scope without management_group_id ------------
run "test14_management_group_scope_missing_id" {
  command = plan

  variables {
    budgets = {
      enterprise = {
        scope_type    = "management_group"
        amount        = 50000
        time_period   = { start_date = "2026-10-01T00:00:00Z" }
        notifications = { w = { threshold = 50, contact_emails = ["a@example.com"] } }
      }
    }
  }

  expect_failures = [var.budgets]
}

#--- Test 15: conflicting scope IDs on one budget ---------------------------
# HCL rejects a literally duplicated map key at parse time, so the
# "duplicate/invalid budget configuration" case a module CAN catch is a budget
# carrying more than one scope ID.
run "test15_conflicting_scope_ids" {
  command = plan

  variables {
    budgets = {
      confused = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        subscription_id   = "/subscriptions/00000000-0000-0000-0000-000000000000"
        amount            = 100
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { w = { threshold = 50, contact_emails = ["a@example.com"] } }
      }
    }
  }

  expect_failures = [var.budgets]
}

#--- contact_groups / contact_roles are unsupported at MG scope -------------
# Without this rule they would be silently dropped rather than rejected.
run "management_group_rejects_contact_roles" {
  command = plan

  variables {
    budgets = {
      enterprise = {
        scope_type          = "management_group"
        management_group_id = "/providers/Microsoft.Management/managementGroups/mg-root"
        amount              = 50000
        time_period         = { start_date = "2026-10-01T00:00:00Z" }
        notifications = {
          w = {
            threshold      = 50
            contact_emails = ["a@example.com"]
            contact_roles  = ["Owner"]
          }
        }
      }
    }
  }

  expect_failures = [var.budgets]
}

#--- Test 10: a budget with no notifications --------------------------------
# The provider declares `notification` Required with MinItems: 1, so zero
# notifications is not a supported configuration.
run "test10_budget_without_notifications_is_rejected" {
  command = plan

  variables {
    budgets = {
      another_service = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-another-service"
        amount            = 500
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = {}
      }
    }
  }

  expect_failures = [var.budgets]
}

#--- A notification with no recipients at all -------------------------------
run "notification_without_any_recipient_is_rejected" {
  command = plan

  variables {
    budgets = {
      openai = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        amount            = 1000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { w = { threshold = 50 } }
      }
    }
  }

  expect_failures = [var.budgets]
}

#--- Provider enums and ranges ----------------------------------------------
# These values reach the resources through for_each, so the provider's own
# ValidateFuncs never see them during the validate walk. Without these module
# rules they would surface only on a credentialed plan.

run "invalid_time_grain_is_rejected" {
  command = plan

  variables {
    budgets = {
      openai = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        amount            = 1000
        time_grain        = "Weekly"
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { w = { threshold = 50, contact_emails = ["a@example.com"] } }
      }
    }
  }

  expect_failures = [var.budgets]
}

run "fractional_threshold_is_rejected" {
  command = plan

  variables {
    budgets = {
      openai = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        amount            = 1000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { w = { threshold = 80.5, contact_emails = ["a@example.com"] } }
      }
    }
  }

  expect_failures = [var.budgets]
}

run "amount_below_one_is_rejected" {
  command = plan

  variables {
    budgets = {
      openai = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        amount            = 0
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { w = { threshold = 50, contact_emails = ["a@example.com"] } }
      }
    }
  }

  expect_failures = [var.budgets]
}

run "invalid_filter_dimension_is_rejected" {
  command = plan

  variables {
    budgets = {
      openai = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        amount            = 1000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { w = { threshold = 50, contact_emails = ["a@example.com"] } }
        filter = {
          dimension = [{ name = "NotADimension", values = ["x"] }]
        }
      }
    }
  }

  expect_failures = [var.budgets]
}

run "empty_filter_is_rejected" {
  command = plan

  variables {
    budgets = {
      openai = {
        scope_type        = "resource_group"
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openai"
        amount            = 1000
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications     = { w = { threshold = 50, contact_emails = ["a@example.com"] } }
        filter            = {}
      }
    }
  }

  expect_failures = [var.budgets]
}

#--- The module must NOT reject these ---------------------------------------
# Guards against the validation rules drifting over-strict. Formats, dates and
# identifiers are deliberately left to the provider and the Azure API, which
# parse them properly.
run "permissive_inputs_are_accepted" {
  command = plan

  variables {
    budgets = {
      "team.openai" = {
        scope_type = "resource_group"
        # Non-canonical casing on the resourceGroups segment.
        resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/RESOURCEGROUPS/rg-openai"
        amount            = 1
        time_period       = { start_date = "2026-10-01T00:00:00Z" }
        notifications = {
          "warn.50" = {
            threshold      = 0
            contact_emails = ["finops+azure@example.co.uk"]
          }
          roles_only = {
            threshold     = 1000
            contact_roles = ["Owner"]
          }
        }
      }
    }
  }

  assert {
    condition     = length(azurerm_consumption_budget_resource_group.this) == 1
    error_message = "permissive but valid input should produce exactly one budget"
  }
}
