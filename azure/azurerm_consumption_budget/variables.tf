variable "budgets" {
  description = <<-DESC
    Azure Consumption Budgets to create, keyed by a stable logical name.

    The map key is Terraform-only: it is never sent to Azure. It is the
    `for_each` key (so it must be stable across runs) and, when `name` is
    omitted, the Azure budget name.

    Each budget picks its own scope, so one invocation can mix scopes:
      scope_type = "subscription"     -> set `subscription_id`
      scope_type = "resource_group"   -> set `resource_group_id`
      scope_type = "management_group" -> set `management_group_id`

    Provider constraints worth knowing before you plan:
      * `notifications` must be non-empty (`notification` is Required, MinItems 1).
      * `time_period` is Required; `start_date` must be the first day of a
        month, RFC3339, on or after 2017-06-01.
      * At management group scope `contact_emails` is Required, and
        `contact_groups` / `contact_roles` do not exist.

    Verified against hashicorp/azurerm 4.81.0.
  DESC

  type = map(object({
    scope_type = string

    # Full ARM resource IDs. azurerm 4.x rejects a bare subscription GUID.
    subscription_id     = optional(string)
    resource_group_id   = optional(string)
    management_group_id = optional(string)

    name       = optional(string) # defaults to the map key
    amount     = number
    time_grain = optional(string, "Monthly")

    time_period = object({
      start_date = string           # RFC3339, first of a month, >= 2017-06-01
      end_date   = optional(string) # Azure defaults to start_date + 10 years
    })

    # A map so each notification has a stable Terraform-side key. The key is a
    # label only -- the provider block has no name argument.
    notifications = map(object({
      threshold      = number
      enabled        = optional(bool, true)
      threshold_type = optional(string, "Actual")

      # The provider declares operator Required with no default of its own;
      # "GreaterThan" is this module's default.
      operator = optional(string, "GreaterThan")

      # list(string), not set(string): the provider models these as TypeList.
      contact_emails = optional(list(string), [])

      # Not available at management group scope (see validation below).
      contact_groups = optional(list(string), [])
      contact_roles  = optional(list(string), [])
    }))

    # dimension and tag are provider sets with no MaxItems, so multiple of each
    # are allowed -- hence lists, not single objects. There is no `not` block
    # in azurerm 4.x.
    filter = optional(object({
      dimension = optional(list(object({
        name     = string
        operator = optional(string, "In")
        values   = list(string)
      })), [])

      tag = optional(list(object({
        name     = string
        operator = optional(string, "In")
        values   = list(string)
      })), [])
    }))

    timeouts = optional(object({
      create = optional(string)
      read   = optional(string)
      update = optional(string)
      delete = optional(string)
    }))
  }))

  #===========================================================================
  # Validation
  #
  # A rule is kept only if BOTH hold:
  #   (a) it cannot reject input the provider would accept -- so it is either a
  #       module-only structural concern, or an enum/range copied verbatim from
  #       the provider source; and
  #   (b) nothing else catches it before apply.
  #
  # (b) is the part that is easy to get wrong here. Values reach the resources
  # through for_each/each.value, so they are not statically known during the
  # validate walk and the provider's own ValidateFuncs never see them.
  # `terraform validate` will happily pass amount = 0 or time_grain = "Weekly".
  # Those only fail on a plan with working Azure credentials -- which a
  # credential-free CI job never runs. So the exact enums below are not
  # redundant with the provider; they are the only pre-apply check there is.
  #
  # Everything requiring interpretation was deliberately DROPPED, because a
  # wrong rule here blocks valid configurations: email regexes, Action Group ID
  # regexes, ARM ID shape regexes, budget/notification key regexes, per-scope
  # name regexes, and RFC3339/first-of-month/end-date date arithmetic. The
  # provider parses IDs and dates properly; guessing at them in HCL does not.
  #===========================================================================

  #--- Module-only: scope routing (the provider can never check these) -------

  validation {
    condition = alltrue([
      for v in values(var.budgets) :
      contains(["subscription", "resource_group", "management_group"], v.scope_type)
    ])
    error_message = format("Invalid scope_type on budget(s): %s. Allowed: subscription, resource_group, management_group.",
      join(", ", [for k, v in var.budgets : format("%q (got %q)", k, v.scope_type)
      if !contains(["subscription", "resource_group", "management_group"], v.scope_type)])
    )
  }

  # Terraform has no tagged-union type, so scope correctness cannot live in the
  # type system. Without this, a mismatched scope ID is silently ignored and the
  # required one arrives null.
  validation {
    condition = alltrue([
      for v in values(var.budgets) : (
        length(compact([v.subscription_id, v.resource_group_id, v.management_group_id])) == 1 &&
        (v.scope_type == "subscription" ? v.subscription_id != null : true) &&
        (v.scope_type == "resource_group" ? v.resource_group_id != null : true) &&
        (v.scope_type == "management_group" ? v.management_group_id != null : true)
      )
    ])
    error_message = format("Each budget must set exactly the one scope ID matching its scope_type. Offending budget(s): %s.",
      join(", ", [for k, v in var.budgets : format("%q (scope_type = %q)", k, v.scope_type)
        if !(
          length(compact([v.subscription_id, v.resource_group_id, v.management_group_id])) == 1 &&
          (v.scope_type == "subscription" ? v.subscription_id != null : true) &&
          (v.scope_type == "resource_group" ? v.resource_group_id != null : true) &&
          (v.scope_type == "management_group" ? v.management_group_id != null : true)
      )])
    )
  }

  # Without this, contact_groups/contact_roles on a management group budget are
  # silently dropped: management_group.tf cannot emit arguments that do not
  # exist on that resource, so the config applies cleanly and never notifies.
  validation {
    condition = alltrue(flatten([
      for v in values(var.budgets) : [
        for n in values(v.notifications) :
        v.scope_type != "management_group" || (length(n.contact_groups) == 0 && length(n.contact_roles) == 0)
      ]
    ]))
    error_message = format("contact_groups and contact_roles do not exist on azurerm_consumption_budget_management_group and would be silently ignored. Offending notification(s): %s.",
      join(", ", flatten([for k, v in var.budgets : [for nk, n in v.notifications : format("%q.%q", k, nk)
      if v.scope_type == "management_group" && (length(n.contact_groups) > 0 || length(n.contact_roles) > 0)]]))
    )
  }

  #--- Exact enums and ranges, copied verbatim from the provider source ------

  # provider: notification is Required, MinItems 1
  validation {
    condition = alltrue([for v in values(var.budgets) : length(v.notifications) > 0])
    error_message = format("Budget(s) %s have no notifications. The provider requires at least one notification block.",
      join(", ", [for k, v in var.budgets : format("%q", k) if length(v.notifications) == 0])
    )
  }

  # provider: validation.FloatAtLeast(1.0)
  validation {
    condition = alltrue([for v in values(var.budgets) : v.amount >= 1])
    error_message = format("amount must be >= 1. Offending budget(s): %s.",
      join(", ", [for k, v in var.budgets : format("%q (got %v)", k, v.amount) if v.amount < 1])
    )
  }

  # provider: StringInSlice, and ForceNew
  validation {
    condition = alltrue([for v in values(var.budgets) :
      contains(["BillingAnnual", "BillingMonth", "BillingQuarter", "Annually", "Monthly", "Quarterly"], v.time_grain)
    ])
    error_message = format("Invalid time_grain on budget(s): %s. Allowed: BillingAnnual, BillingMonth, BillingQuarter, Annually, Monthly, Quarterly.",
      join(", ", [for k, v in var.budgets : format("%q (got %q)", k, v.time_grain)
      if !contains(["BillingAnnual", "BillingMonth", "BillingQuarter", "Annually", "Monthly", "Quarterly"], v.time_grain)])
    )
  }

  # provider: TypeInt with validation.IntBetween(0, 1000)
  validation {
    condition = alltrue(flatten([for v in values(var.budgets) : [
      for n in values(v.notifications) : n.threshold >= 0 && n.threshold <= 1000 && floor(n.threshold) == n.threshold
    ]]))
    error_message = format("threshold must be a whole number between 0 and 1000 (a percentage of amount). Offending notification(s): %s.",
      join(", ", flatten([for k, v in var.budgets : [for nk, n in v.notifications : format("%q.%q (got %v)", k, nk, n.threshold)
      if !(n.threshold >= 0 && n.threshold <= 1000 && floor(n.threshold) == n.threshold)]]))
    )
  }

  # provider: StringInSlice
  validation {
    condition = alltrue(flatten([for v in values(var.budgets) : [
      for n in values(v.notifications) : contains(["EqualTo", "GreaterThan", "GreaterThanOrEqualTo"], n.operator)
    ]]))
    error_message = format("Invalid notification operator(s): %s. Allowed: EqualTo, GreaterThan, GreaterThanOrEqualTo.",
      join(", ", flatten([for k, v in var.budgets : [for nk, n in v.notifications : format("%q.%q (got %q)", k, nk, n.operator)
      if !contains(["EqualTo", "GreaterThan", "GreaterThanOrEqualTo"], n.operator)]]))
    )
  }

  # provider: StringInSlice
  validation {
    condition = alltrue(flatten([for v in values(var.budgets) : [
      for n in values(v.notifications) : contains(["Actual", "Forecasted"], n.threshold_type)
    ]]))
    error_message = format("Invalid threshold_type(s): %s. Allowed: Actual, Forecasted.",
      join(", ", flatten([for k, v in var.budgets : [for nk, n in v.notifications : format("%q.%q (got %q)", k, nk, n.threshold_type)
      if !contains(["Actual", "Forecasted"], n.threshold_type)]]))
    )
  }

  # provider note: a notification cannot have contact_emails, contact_groups
  # and contact_roles all empty. At MG scope contact_emails is Required.
  validation {
    condition = alltrue(flatten([for v in values(var.budgets) : [
      for n in values(v.notifications) :
      v.scope_type == "management_group"
      ? length(n.contact_emails) > 0
      : length(n.contact_emails) + length(n.contact_groups) + length(n.contact_roles) > 0
    ]]))
    error_message = format("Every notification needs at least one recipient (management group scope requires contact_emails specifically). Offending notification(s): %s.",
      join(", ", flatten([for k, v in var.budgets : [for nk, n in v.notifications : format("%q.%q", k, nk)
        if !(v.scope_type == "management_group"
          ? length(n.contact_emails) > 0
      : length(n.contact_emails) + length(n.contact_groups) + length(n.contact_roles) > 0)]]))
    )
  }

  # provider: StringInSlice(getDimensionNames())
  validation {
    condition = alltrue(flatten([for v in values(var.budgets) : [
      for d in(v.filter == null ? [] : v.filter.dimension) : contains([
        "ChargeType", "Frequency", "InvoiceId", "Meter", "MeterCategory",
        "MeterSubCategory", "PartNumber", "PricingModel", "Product",
        "ProductOrderId", "ProductOrderName", "PublisherType", "ReservationId",
        "ReservationName", "ResourceGroupName", "ResourceGuid", "ResourceId",
        "ResourceLocation", "ResourceType", "ServiceFamily", "ServiceName",
        "SubscriptionID", "SubscriptionName", "UnitOfMeasure",
      ], d.name)
    ]]))
    error_message = "Invalid filter dimension name. Allowed: ChargeType, Frequency, InvoiceId, Meter, MeterCategory, MeterSubCategory, PartNumber, PricingModel, Product, ProductOrderId, ProductOrderName, PublisherType, ReservationId, ReservationName, ResourceGroupName, ResourceGuid, ResourceId, ResourceLocation, ResourceType, ServiceFamily, ServiceName, SubscriptionID, SubscriptionName, UnitOfMeasure."
  }

  # provider: StringInSlice(["In"]) on both dimension and tag
  validation {
    condition = alltrue(flatten([for v in values(var.budgets) : [
      for f in(v.filter == null ? [] : concat(v.filter.dimension, v.filter.tag)) : f.operator == "In"
    ]]))
    error_message = "filter dimension.operator and tag.operator accept only \"In\"."
  }

  # provider: AtLeastOneOf ["filter.0.dimension", "filter.0.tag"].
  # `filter = {}` would otherwise emit an empty block and fail at apply.
  validation {
    condition = alltrue([
      for v in values(var.budgets) :
      v.filter == null ? true : length(v.filter.dimension) + length(v.filter.tag) > 0
    ])
    error_message = format("A filter must contain at least one dimension or tag; omit `filter` entirely to not filter. Offending budget(s): %s.",
      join(", ", [for k, v in var.budgets : format("%q", k)
      if v.filter != null && length(v.filter.dimension) + length(v.filter.tag) == 0])
    )
  }
}
