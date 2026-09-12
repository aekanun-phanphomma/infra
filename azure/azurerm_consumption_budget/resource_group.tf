resource "azurerm_consumption_budget_resource_group" "this" {
  for_each = local.resource_group_budgets

  name              = local.budget_names[each.key]
  resource_group_id = each.value.resource_group_id
  amount            = each.value.amount
  time_grain        = each.value.time_grain

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

      contact_emails = length(notification.value.contact_emails) > 0 ? notification.value.contact_emails : null
      contact_groups = length(notification.value.contact_groups) > 0 ? notification.value.contact_groups : null
      contact_roles  = length(notification.value.contact_roles) > 0 ? notification.value.contact_roles : null
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
