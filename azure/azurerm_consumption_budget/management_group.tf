# The provider overrides the shared notification schema for this resource:
# contact_emails is Required (MinItems 1), and contact_groups / contact_roles
# do not exist. The notification block below is therefore deliberately not a
# copy of the other two files. Variable validation rejects those two arguments
# at this scope so the mismatch fails loudly instead of being dropped.

resource "azurerm_consumption_budget_management_group" "this" {
  for_each = local.management_group_budgets

  name                = local.budget_names[each.key]
  management_group_id = each.value.management_group_id
  amount              = each.value.amount
  time_grain          = each.value.time_grain

  time_period {
    start_date = each.value.time_period.start_date
    end_date   = each.value.time_period.end_date
  }

  dynamic "notification" {
    for_each = each.value.notifications

    content {
      enabled        = notification.value.enabled
      threshold      = notification.value.threshold
      operator       = notification.value.operator
      threshold_type = notification.value.threshold_type

      # Required here, so passed through unconditionally rather than
      # collapsed to null when empty.
      contact_emails = notification.value.contact_emails
    }
  }

  dynamic "filter" {
    for_each = each.value.filter != null ? [each.value.filter] : []

    content {
      dynamic "dimension" {
        for_each = filter.value.dimension

        content {
          name     = dimension.value.name
          operator = dimension.value.operator
          values   = dimension.value.values
        }
      }

      dynamic "tag" {
        for_each = filter.value.tag

        content {
          name     = tag.value.name
          operator = tag.value.operator
          values   = tag.value.values
        }
      }
    }
  }

  dynamic "timeouts" {
    for_each = each.value.timeouts != null ? [each.value.timeouts] : []

    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}
