resource "azurerm_consumption_budget_subscription" "this" {
  # Keyed by the logical budget key, so the address is ...this["platform"]
  # rather than ...this[0]: reordering budgets never causes replacement.
  for_each = local.subscription_budgets

  name            = local.budget_names[each.key]
  subscription_id = each.value.subscription_id
  amount          = each.value.amount
  time_grain      = each.value.time_grain

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

      # Collapsed to null so an unused channel is absent from the request
      # rather than sent as an empty array.
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

  # `etag` is settable but is an Azure concurrency token, not user config.
  # Exposed read-only via the budget_etags output instead.
}
