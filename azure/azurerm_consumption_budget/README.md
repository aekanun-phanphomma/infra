# terraform-azurerm-consumption-budget

A single, reusable Terraform module that manages **Azure Consumption Budgets at all three
Azure RBAC scopes** — subscription, resource group and management group — from one
strongly typed input map.

The caller does not need three modules. One `module` block, one `budgets` map, and each
budget picks its own scope.

---

## Contents

- [Overview](#overview)
- [Supported resources](#supported-resources)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Azure permissions](#azure-permissions)
- [Provider schema differences between the three scopes](#provider-schema-differences-between-the-three-scopes)
- [Usage](#usage)
- [Multi-budget usage](#multi-budget-usage)
- [Multi-scope usage](#multi-scope-usage)
- [Notifications](#notifications)
- [Multiple email recipients](#multiple-email-recipients)
- [Filters](#filters)
- [Input variables](#input-variables)
- [Outputs](#outputs)
- [Terraform address stability](#terraform-address-stability)
- [Scope migration warning](#scope-migration-warning)
- [Import](#import)
- [Validation rules](#validation-rules)
- [Version compatibility](#version-compatibility)
- [Known limitations](#known-limitations)
- [Testing](#testing)
- [Code quality and Trunk](#code-quality-and-trunk)

---

## Overview

Azure exposes consumption budgets as three separate ARM resource types, one per RBAC
scope. The AzureRM provider mirrors that with three separate Terraform resources. Managing
a real estate of budgets therefore normally means either three modules, or one module with
`count` and index-based addressing that churns state whenever a list is reordered.

This module takes a different approach:

- **One interface.** A single `budgets` map, keyed by a logical name you choose.
- **Per-budget scope selection.** `scope_type` lives on each budget, not on the module, so
  a single invocation can create budgets at all three scopes at once.
- **`for_each` on the logical key.** Resource addresses are
  `...this["openai"]`, never `...this[0]`, so reordering never causes replacement.
- **Provider-accurate.** The unified interface does *not* flatten the three resources into
  a fake common schema. Where the provider differs — and it does, materially — the module
  models the difference and validates it.
- **Fails in Terraform, not in Azure.** 13 validation rules reject bad input with a message
  naming the offending budget key, rather than surfacing an opaque Azure 400. They are
  deliberately limited to checks that cannot reject input the provider would accept — see
  [Validation rules](#validation-rules).

---

## Supported resources

| Terraform resource | Scope |
| --- | --- |
| `azurerm_consumption_budget_subscription` | Subscription |
| `azurerm_consumption_budget_resource_group` | Resource group |
| `azurerm_consumption_budget_management_group` | Management group |

---

## Architecture

```text
                        module "consumption_budgets"
                                    |
                              var.budgets                    (map(object))
                                    |
                    +---------------+---------------+
                    |               |               |
            scope_type =    scope_type =     scope_type =
           "subscription"  "resource_group" "management_group"
                    |               |               |
                 for_each        for_each        for_each        (keyed by logical name)
                    |               |               |
   azurerm_consumption_   azurerm_consumption_   azurerm_consumption_
     budget_subscription   budget_resource_group  budget_management_group
                    |               |               |
              dynamic "notification" (one block per notifications map entry)
                    |               |               |
              contact_emails / contact_groups / contact_roles
              (management group scope: contact_emails only)
```

Concretely, this shape:

```text
                    consumption-budget
                           |
                     var.budgets
                           |
          +----------------+----------------+
          |                |                |
        OpenAI       Azure Foundry     Another Service
          |                |                |
       RG scope         RG scope       Subscription
          |                |                |
     notifications   notifications    notifications
        |    |           |    |            |
      50%  80%         50%  80%          80%
       |    |           |    |            |
     emails emails    emails emails     emails
```

---

## Requirements

| Name | Version |
| --- | --- |
| Terraform | `>= 1.6.0` |
| `hashicorp/azurerm` | `~> 4.0` (implemented and verified against **4.81.0**) |

Why `>= 1.6.0`:

- `optional(<type>, <default>)` object attribute defaults — Terraform 1.3+
- expressions in `validation.error_message` — Terraform 1.3+
- the native `terraform test` framework used in [`tests/`](tests/) — Terraform 1.6+

Why `~> 4.0` rather than `>= 3.0`: this module is written against the 4.x schema. In
particular, azurerm 4.x validates `subscription_id` with `commonids.ValidateSubscriptionID`
(full resource ID required), and 4.x has **no `not` block** inside `filter`. A 5.x major
release may rename or remove arguments, so it is excluded.

### No provider configuration inside the module

This module contains **no `provider "azurerm"` block** and hardcodes no subscription,
tenant, client ID, secret, or authentication method. The root module configures the
provider and this module inherits it — see any of the [`examples/`](examples/).

---

## Azure permissions

Verified against Microsoft Learn (Cost Management + Billing docs):

| Task | Required |
| --- | --- |
| Create / modify / delete budgets | **Owner**, **Contributor**, or **Cost Management Contributor** on the scope (i.e. `Microsoft.Consumption/budgets/write`) |
| View budgets | **Reader** or **Cost Management Reader** |
| Use `contact_groups` (Action Groups) | Additionally **Monitoring Reader** (`Microsoft.Insights/actionGroups/read`) on the action group |

Two platform caveats worth knowing before you plan:

- On a **brand-new subscription** it can take **up to 48 hours** before budgets can be
  created at all.
- Budget evaluation requires **a single currency across the whole scope**. A management
  group spanning subscriptions in different billing currencies will not evaluate correctly.

---

## Provider schema differences between the three scopes

**This is the most important thing to know about this module.** The three resources are
*not* interchangeable. The provider defines a shared base schema, then
`azurerm_consumption_budget_management_group` **overrides the notification block** with a
reduced model (`ConsumptionBudgetMgmtNotificationModel`):

| `notification` argument | subscription | resource group | management group |
| --- | --- | --- | --- |
| `enabled` | Optional (default `true`) | Optional (default `true`) | Optional (default `true`) |
| `threshold` | Required, `0`–`1000` | Required, `0`–`1000` | Required, `0`–`1000` |
| `threshold_type` | Optional (`Actual` \| `Forecasted`) | Optional | Optional |
| `operator` | Required | Required | Required |
| `contact_emails` | Optional | Optional | **Required, min 1** |
| `contact_groups` | Optional | Optional | **Does not exist** |
| `contact_roles` | Optional | Optional | **Does not exist** |

This is not a provider oversight. Microsoft's own documentation states that *action groups
are currently only supported for subscription and resource group scopes*.

Other per-resource differences:

| | subscription | resource group | management group |
| --- | --- | --- | --- |
| Scope argument | `subscription_id` | `resource_group_id` | `management_group_id` |
| Scope validator | `commonids.ValidateSubscriptionID` | `ResourceGroupID` | `ManagementGroupID` |
| `name` validator | `^[-_a-zA-Z0-9]{1,63}$` | non-whitespace | non-whitespace |

The module **does not silently drop** the unsupported arguments at management group scope.
Setting `contact_groups` or `contact_roles` on a management group budget is a hard
validation error that tells you exactly why.

Everything else — `amount`, `time_grain`, `time_period`, `filter`, `timeouts`, `etag` — is
shared and identical across all three.

---

## Usage

```hcl
module "consumption_budgets" {
  source = "./modules/consumption-budget"

  budgets = {
    platform = {
      scope_type      = "subscription"
      subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"

      name       = "budget-platform"
      amount     = 5000
      time_grain = "Monthly"

      time_period = {
        start_date = "2026-10-01T00:00:00Z"
      }

      notifications = {
        warning = {
          threshold      = 80
          operator       = "GreaterThan"
          contact_emails = ["owner@example.com"]
        }
      }
    }
  }
}
```

Runnable examples:

| Example | Shows |
| --- | --- |
| [`examples/subscription`](examples/subscription/) | A single subscription budget |
| [`examples/resource-group`](examples/resource-group/) | Three resource groups, multiple notifications, action groups, filters |
| [`examples/management-group`](examples/management-group/) | Management group scope and its reduced notification schema |
| [`examples/mixed`](examples/mixed/) | **All three scopes in one invocation** |

---

## Multi-budget usage

Add entries to the map. Each key becomes an independent budget resource:

```hcl
budgets = {
  openai = {
    scope_type        = "resource_group"
    resource_group_id = "/subscriptions/xxx/resourceGroups/rg-openai"
    amount            = 1000
    time_period       = { start_date = "2026-10-01T00:00:00Z" }
    notifications     = { warning = { threshold = 80, contact_emails = ["a@example.com"] } }
  }

  azure_foundry = {
    scope_type        = "resource_group"
    resource_group_id = "/subscriptions/xxx/resourceGroups/rg-azure-foundry"
    amount            = 2000
    time_period       = { start_date = "2026-10-01T00:00:00Z" }
    notifications     = { warning = { threshold = 80, contact_emails = ["a@example.com"] } }
  }

  another_service = {
    scope_type        = "resource_group"
    resource_group_id = "/subscriptions/xxx/resourceGroups/rg-another-service"
    amount            = 500
    time_period       = { start_date = "2026-10-01T00:00:00Z" }
    notifications     = { warning = { threshold = 80, contact_emails = ["a@example.com"] } }
  }
}
```

That produces three fully independent resources:

```text
azurerm_consumption_budget_resource_group.this["openai"]
azurerm_consumption_budget_resource_group.this["azure_foundry"]
azurerm_consumption_budget_resource_group.this["another_service"]
```

The module assumes nothing about how many budgets, resource groups, subscriptions or
scopes are in play. Multiple resource groups in the same subscription is just three map
entries.

`name` is optional. When omitted it defaults to the map key, so `openai` above would create
an Azure budget literally named `openai`. Set `name` explicitly when the Azure-side name
should differ from your Terraform-side key.

---

## Multi-scope usage

Scope is a per-budget decision, so scopes can be mixed freely in one invocation:

```hcl
budgets = {
  platform      = { scope_type = "subscription",     subscription_id     = "/subscriptions/xxx",                                          ... }
  openai        = { scope_type = "resource_group",   resource_group_id   = "/subscriptions/xxx/resourceGroups/rg-openai",                  ... }
  azure_foundry = { scope_type = "resource_group",   resource_group_id   = "/subscriptions/xxx/resourceGroups/rg-azure-foundry",           ... }
  enterprise    = { scope_type = "management_group", management_group_id = "/providers/Microsoft.Management/managementGroups/mg-root",     ... }
}
```

Terraform creates three different resource *types* from that one call:

```text
azurerm_consumption_budget_subscription.this["platform"]
azurerm_consumption_budget_resource_group.this["openai"]
azurerm_consumption_budget_resource_group.this["azure_foundry"]
azurerm_consumption_budget_management_group.this["enterprise"]
```

See [`examples/mixed`](examples/mixed/) for the complete working configuration.

---

## Notifications

The provider's `notification` is a **set block with `MinItems: 1`** — every budget must
have at least one, and a budget cannot be created without notifications.

This module models notifications as a **map**, not a list:

```hcl
notifications = {
  warning = {
    threshold      = 50
    operator       = "GreaterThan"
    contact_emails = ["owner@example.com"]
  }

  critical = {
    threshold      = 80
    operator       = "GreaterThan"
    contact_emails = ["owner@example.com", "finance@example.com"]
  }

  exceeded = {
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    contact_emails = ["owner@example.com", "finance@example.com"]
    contact_roles  = ["Owner"]
  }

  forecast_overrun = {
    threshold      = 100
    threshold_type = "Forecasted"
    contact_emails = ["finance@example.com"]
  }
}
```

**The map key is Terraform-side only and is never sent to Azure.** The provider's
notification block has no name or key argument. The key exists so that each notification
has a stable, readable identity in your configuration — adding `critical` later does not
disturb `warning`.

A `dynamic "notification"` block expands the map into one provider block per entry.

Notification arguments, all verified against the provider schema:

| Argument | Type | Required | Allowed values / range |
| --- | --- | --- | --- |
| `threshold` | `number` | yes | whole number `0`–`1000` (percentage of `amount`) |
| `operator` | `string` | provider: yes | `EqualTo`, `GreaterThan`, `GreaterThanOrEqualTo` |
| `threshold_type` | `string` | no (default `Actual`) | `Actual`, `Forecasted` |
| `enabled` | `bool` | no (default `true`) | |
| `contact_emails` | `list(string)` | see scope table | |
| `contact_groups` | `list(string)` | no — **not at MG scope** | Action Group resource IDs |
| `contact_roles` | `list(string)` | no — **not at MG scope** | e.g. `Owner`, `Contributor`, `Reader` |

Two notes on `operator`:

- The provider declares it **Required with no default**. This module defaults it to
  `GreaterThan` for ergonomics — that default is a *module* opinion, not provider
  behaviour. Set it explicitly whenever you mean something else.
- `threshold` is `TypeInt` on the provider side, so `80.5` is rejected. The module checks
  this rather than letting the provider fail later.

`contact_roles` values are **not** enumerated by the provider, so this module does not
restrict them either.

---

## Multiple email recipients

`contact_emails` is a `list(string)` — matching the provider's `TypeList`, *not* a set.
Order is preserved and any number of recipients is supported, independently per
notification:

```hcl
notifications = {
  warning = {
    threshold = 50
    contact_emails = [
      "owner@example.com",
      "devops@example.com",
    ]
  }

  critical = {
    threshold = 80
    contact_emails = [
      "owner@example.com",
      "devops@example.com",
      "finance@example.com",
    ]
  }
}
```

Every notification needs **at least one** recipient across `contact_emails`,
`contact_groups` and `contact_roles` (the provider rejects a notification with all three
empty). At management group scope, `contact_emails` specifically must be non-empty.

Email validation is deliberately permissive (`local@domain.tld`, no whitespace) so that
plus-addressing and unusual TLDs are not rejected — the provider itself only requires a
non-empty string.

---

## Filters

`filter` is optional. When present it must contain at least one `dimension` or one `tag`
(the provider sets `AtLeastOneOf` on those two).

Both `dimension` and `tag` are **sets with no `MaxItems`**, so **multiple of each are
allowed**. This module models them as lists of objects accordingly:

```hcl
filter = {
  dimension = [
    {
      name   = "ResourceType"
      values = ["microsoft.compute/virtualmachines", "microsoft.storage/storageaccounts"]
    },
    {
      name   = "ResourceLocation"
      values = ["southeastasia"]
    },
  ]

  tag = [
    {
      name   = "costCenter"
      values = ["cc-1234"]
    },
  ]
}
```

- `dimension.name` must be one of 24 values: `ChargeType`, `Frequency`, `InvoiceId`,
  `Meter`, `MeterCategory`, `MeterSubCategory`, `PartNumber`, `PricingModel`, `Product`,
  `ProductOrderId`, `ProductOrderName`, `PublisherType`, `ReservationId`,
  `ReservationName`, `ResourceGroupName`, `ResourceGuid`, `ResourceId`, `ResourceLocation`,
  `ResourceType`, `ServiceFamily`, `ServiceName`, `SubscriptionID`, `SubscriptionName`,
  `UnitOfMeasure`.
- `tag.name` is free-form.
- `operator` on both defaults to `In`, and **`In` is the only value the provider accepts**.
- `dimension.values` requires at least one value.

> There is **no `not` block** in azurerm 4.x. It is not modelled here. If you have seen it
> in older examples, that was a 3.x-era schema.

---

## Input variables

The module exposes exactly one variable, `budgets`, of type
`map(object({...}))`. `any` is not used anywhere.

### Top level (per budget)

| Attribute | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `scope_type` | `string` | yes | | `subscription` \| `resource_group` \| `management_group` |
| `subscription_id` | `string` | when `scope_type = "subscription"` | `null` | `/subscriptions/<guid>` — full resource ID, not a bare GUID |
| `resource_group_id` | `string` | when `scope_type = "resource_group"` | `null` | `/subscriptions/<guid>/resourceGroups/<name>` |
| `management_group_id` | `string` | when `scope_type = "management_group"` | `null` | `/providers/Microsoft.Management/managementGroups/<name>` |
| `name` | `string` | no | the map key | ForceNew |
| `amount` | `number` | yes | | must be `>= 1` |
| `time_grain` | `string` | no | `"Monthly"` | `BillingAnnual`, `BillingMonth`, `BillingQuarter`, `Annually`, `Monthly`, `Quarterly`. ForceNew |
| `time_period` | `object` | **yes** | | provider block is Required |
| `notifications` | `map(object)` | **yes, non-empty** | | provider block is Required, `MinItems: 1` |
| `filter` | `object` | no | `null` | |
| `timeouts` | `object` | no | `null` | `create` / `read` / `update` / `delete` |

### `time_period`

| Attribute | Type | Required | Notes |
| --- | --- | --- | --- |
| `start_date` | `string` | yes | RFC3339, **first day of a month**, on or after `2017-06-01`. ForceNew |
| `end_date` | `string` | no | RFC3339. Azure defaults to `start_date` + 10 years |

### `notifications` (map value)

See the [Notifications](#notifications) table above.

### `filter`

| Attribute | Type | Required | Default |
| --- | --- | --- | --- |
| `dimension` | `list(object({ name, operator, values }))` | no | `[]` |
| `tag` | `list(object({ name, operator, values }))` | no | `[]` |

Within each: `name` is `string` (required), `operator` is `string` (default `"In"`),
`values` is `list(string)` (required).

### Not exposed: `etag`

`etag` is `Optional + Computed` on all three resources, but it is an Azure **concurrency
token**, not user-owned configuration. Accepting it as an input invites lost-update
errors. It is surfaced read-only through the `budget_etags` output instead.

---

## Outputs

| Output | Type | Description |
| --- | --- | --- |
| `budget_ids` | `map(string)` | Logical budget key → Azure budget resource ID, flattened across all three scopes |
| `budget_names` | `map(string)` | Logical budget key → the Azure budget name actually created |
| `budget_ids_by_scope` | `object` | IDs grouped under `subscription`, `resource_group`, `management_group`; each key always present, possibly empty |
| `budget_scope_types` | `map(string)` | Logical budget key → the scope it was routed to (tells you which import command applies) |
| `budget_etags` | `map(string)` | Logical budget key → Azure-assigned ETag |

All outputs are keyed by **your** logical budget key, so callers never need to know which
of the three resource types a budget became. The three source maps merge without collision
because a logical key belongs to exactly one scope partition.

---

## Terraform address stability

The module uses `for_each` over a **map**, never `count` over a list. That is a deliberate
state-safety decision.

With `count` and a list:

```text
azurerm_consumption_budget_resource_group.this[0]   # openai
azurerm_consumption_budget_resource_group.this[1]   # azure_foundry
azurerm_consumption_budget_resource_group.this[2]   # another_service
```

Deleting `openai` shifts every later element down one index. Terraform sees `[0]` change
from `openai` to `azure_foundry` and `[2]` disappear, and plans to **destroy and recreate
budgets that you never touched**.

With `for_each` and a map:

```text
azurerm_consumption_budget_resource_group.this["openai"]
azurerm_consumption_budget_resource_group.this["azure_foundry"]
azurerm_consumption_budget_resource_group.this["another_service"]
```

Deleting `openai` destroys exactly `...this["openai"]`. Reordering the map in source
changes nothing at all — HCL maps are unordered, and the address is derived from the key.

This is why budget keys are validated against `^[a-zA-Z0-9_-]{1,63}$`: the key is a
Terraform address, so it should stay simple and stable. **Renaming a key is a
destroy-and-recreate**, not a rename — use `terraform state mv` (or a `moved` block) if you
need to rename one without recreating it:

```bash
terraform state mv \
  'module.consumption_budgets.azurerm_consumption_budget_resource_group.this["old_key"]' \
  'module.consumption_budgets.azurerm_consumption_budget_resource_group.this["new_key"]'
```

The same reasoning applies to the `notifications` map keys.

---

## Scope migration warning

> **Changing `scope_type` on an existing budget is not an in-place update.**

Because each scope maps to a *different Terraform resource type*, changing:

```hcl
scope_type = "resource_group"
```

to:

```hcl
scope_type = "subscription"
```

moves the budget from one resource address to a completely different one:

```text
azurerm_consumption_budget_resource_group.this["foo"]
        ->
azurerm_consumption_budget_subscription.this["foo"]
```

Terraform will plan to **destroy** the resource group budget and **create** a subscription
budget. This module deliberately does **not** implement automatic migration logic — silent
destruction of cost controls is not a behaviour a module should choose on your behalf.

These are also genuinely different Azure resources at different scopes, so there is no
in-place Azure operation that could be performed instead. If you want to preserve
history/state rather than recreate, migrate the state explicitly:

```bash
terraform state mv \
  'module.consumption_budgets.azurerm_consumption_budget_resource_group.this["foo"]' \
  'module.consumption_budgets.azurerm_consumption_budget_subscription.this["foo"]'
```

Then run `terraform plan` and confirm the result before applying. Note that the underlying
Azure resource IDs differ between scopes, so in most cases a destroy/create (or a
`terraform import` at the new scope) is the honest path — verify carefully rather than
assuming `state mv` alone is sufficient.

---

## Import

Verified against the official provider documentation for v4.81.0. Do not guess these
formats — the budget resource ID is scope-prefixed.

**Subscription:**

```bash
terraform import azurerm_consumption_budget_subscription.example \
  /subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Consumption/budgets/subscription1
```

**Resource group:**

```bash
terraform import azurerm_consumption_budget_resource_group.example \
  /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/resourceGroup1/providers/Microsoft.Consumption/budgets/resourceGroup1
```

**Management group:**

```bash
terraform import azurerm_consumption_budget_management_group.example \
  /providers/Microsoft.Management/managementGroups/00000000-0000-0000-0000-000000000000/providers/Microsoft.Consumption/budgets/budget1
```

When importing into this module, address the instance by its logical key:

```bash
terraform import \
  'module.consumption_budgets.azurerm_consumption_budget_resource_group.this["openai"]' \
  /subscriptions/.../resourceGroups/rg-openai/providers/Microsoft.Consumption/budgets/budget-openai
```

Use the `budget_scope_types` output to confirm which resource type a given logical key maps
to.

---

## Validation rules

The module enforces **13** validation rules on `budgets`. Each failure message names the
offending budget key (and notification key, where relevant).

### What gets validated, and why not more

A rule is kept only if **both** hold:

1. **It cannot reject input the provider would accept.** So it is either a module-only
   structural concern, or an enum/range copied verbatim from the provider source.
2. **Nothing else catches it before apply.**

Point 2 is the subtle one. Budget values reach the resources through `for_each` /
`each.value`, so they are **not statically known during the validate walk** — the
provider's own `ValidateFunc`s never see them. `terraform validate` will happily pass
`amount = 0` or `time_grain = "Weekly"` through this module. Those only fail on a plan with
working Azure credentials, which a credential-free CI job never runs.

So the exact enums below are **not** redundant with the provider. For a `for_each`-driven
module they are the only pre-apply check that exists.

Everything requiring *interpretation* was deliberately **dropped**, because a wrong rule
blocks valid configurations — the failure mode is worse than the one it prevents:

| Dropped | Why |
| --- | --- |
| Email regex | Would reject valid addresses (plus-addressing, long TLDs). The provider only requires a non-empty string |
| Action Group ID regex | Same risk, no provider equivalent |
| Subscription / resource group / management group ID regexes | The provider parses these properly; an HCL regex guesses at casing and segment rules |
| Budget key and notification key regexes | Terraform accepts any string as a `for_each` key |
| Per-scope budget name regex | The provider applies a different rule per scope |
| `start_date` RFC3339 / first-of-month / `>= 2017-06-01` | `formatdate` normalises to UTC, so a non-UTC offset could be mis-judged by a day |
| `end_date > start_date` | Same date-arithmetic risk |

### The 13 rules

**Module-only — the provider can never check these:**

| # | Rule |
| --- | --- |
| 1 | `scope_type` is one of `subscription`, `resource_group`, `management_group` |
| 2 | Exactly the one scope ID matching `scope_type` is set, and no others |
| 3 | `contact_groups` / `contact_roles` are not used at management group scope |

Rule 3 prevents **silent data loss**: `management_group.tf` cannot emit arguments that do
not exist on that resource, so without it the misconfiguration applies cleanly and simply
never notifies anyone.

**Exact enums and ranges, copied verbatim from the provider source:**

| # | Rule | Provider equivalent |
| --- | --- | --- |
| 4 | `notifications` is non-empty | `notification` Required, `MinItems: 1` |
| 5 | `amount >= 1` | `validation.FloatAtLeast(1.0)` |
| 6 | `time_grain` is one of six values | `validation.StringInSlice` |
| 7 | `threshold` is a whole number in `0`–`1000` | `TypeInt` + `validation.IntBetween(0, 1000)` |
| 8 | `operator` is one of three values | `validation.StringInSlice` |
| 9 | `threshold_type` is `Actual` or `Forecasted` | `validation.StringInSlice` |
| 10 | Every notification has at least one recipient (non-empty `contact_emails` at MG scope) | Provider note + MG `MinItems: 1` |
| 11 | `filter` dimension name is one of 24 values | `validation.StringInSlice(getDimensionNames())` |
| 12 | `filter` dimension/tag `operator` is `In` | `validation.StringInSlice(["In"])` |
| 13 | A `filter`, if present, has at least one dimension or tag | `AtLeastOneOf` |

`tests/run_validation_tests.sh` includes a **"Deliberately NOT rejected"** group that
asserts the dropped rules stay dropped — a plus-addressed email, a dotted budget key,
non-canonical ARM ID casing and a roles-only notification must all pass. That is the
regression guard against these rules drifting over-strict again.


---
## Version compatibility

| | |
| --- | --- |
| Provider version implemented against | `hashicorp/azurerm` **4.81.0** |
| Declared constraint | `~> 4.0` |
| Schema verification method | `terraform providers schema -json`, cross-checked against the provider source and website docs at git tag `v4.81.0` |
| Azure API used by the provider | `Microsoft.Consumption` `2019-10-01` |

Nothing in this module was written from memory or assumption. Every argument, nested block,
type, enum, default and validation range was read out of the provider's actual schema or
its Go source.

---

## Known limitations

These are real constraints, not module shortcomings. They are listed rather than hidden.

### Azure and the Consumption API

- **Budgets cannot be created on a subscription less than ~48 hours old.** Cost Management
  features are not immediately available on new subscriptions.
- **Single-currency requirement.** Budget evaluation across a scope requires all
  subscriptions in that scope to use one currency. Mixed-currency management groups may
  silently miss alerts.
- **Action groups are subscription/resource-group only.** This is why `contact_groups`
  does not exist at management group scope.
- **Budget evaluation uses actual cost, not amortized cost.** Reservation and purchase
  charges are included in evaluations.

### AzureRM provider

- **`notification` is Required with `MinItems: 1`.** A budget with zero notifications is
  not expressible. The module rejects `notifications = {}` with an explanatory message
  rather than letting it fail later. This makes "a budget without notifications" an
  unsupported configuration, not a supported test case.
- **`time_period` is Required.** It cannot be omitted, and `start_date` must be the first
  of a month. There is no way to say "start now".
- **`threshold` is `TypeInt`.** Fractional thresholds such as `87.5%` are impossible.
- **`filter` operators accept only `In`.** No negation or exclusion is available; the
  `not` block present in azurerm 3.x does not exist in 4.x.
- **`contact_roles` values are unvalidated by the provider**, so a typo like `"Onwer"`
  reaches Azure. The module does not invent an enum the provider does not have.
- **`end_date` is `Computed`.** If you omit it, Azure assigns `start_date` + 10 years and
  Terraform records that value; adding an explicit `end_date` later shows as a change.

### Terraform

- **Provider validation is invisible to `terraform validate` in this module.** Values
  reach the resources through `for_each` / `each.value`, so they are not statically known
  during the validate walk and the provider's `ValidateFunc`s never run against them.
  `terraform validate` passes configurations the provider would reject. This is why the
  module keeps its own copies of the provider's exact enums and ranges — see
  [Validation rules](#validation-rules).
- **Format and date correctness is only checked at apply.** Email addresses, Action Group
  IDs, ARM ID shapes and `start_date` being the first of a month are deliberately left to
  the provider and the Azure API, because an HCL approximation of those rules would reject
  valid input. Expect those failures at apply, not at plan.
- **Changing `scope_type` is a destroy/create**, not an update. See
  [Scope migration warning](#scope-migration-warning).
- **Renaming a budget key or a notification key is a destroy/create**, because the key is
  part of the resource address. Use `terraform state mv` or a `moved` block.
- **`name`, the scope ID, `time_grain` and `time_period.start_date` are all ForceNew.**
  Changing any of them replaces the budget.
- **Terraform has no tagged-union type.** A single `object` type must hold the union of
  all three scopes' attributes, so scope-correctness is enforced by `validation` blocks
  rather than by the type system.
- **`terraform test` requires working Azure credentials even for pure input-validation
  cases**, because providers are configured before any run block executes. See
  [Testing](#testing).

---

## Testing

Two complementary layers live in [`tests/`](tests/).

### 1. Native Terraform tests — `tests/*.tftest.hcl`

The canonical suite: 31 `run` blocks across three files, all `command = plan` (nothing is
created in Azure).

| File | Covers |
| --- | --- |
| `scopes.tftest.hcl` | Tests 1, 2, 3, 4, 9, 16 — scope routing, per-instance isolation, address stability |
| `notifications.tftest.hcl` | Tests 5, 6, 7, 8 — notification fan-out, multiple recipients, filters, MG reduced schema |
| `validation.tftest.hcl` | Tests 10–15 and the remaining rejection rules via `expect_failures`, plus one run asserting that permissive-but-valid input is **not** rejected |

```bash
terraform test
```

**Requires Azure credentials.** `terraform test` configures providers before executing any
run block, so without a valid Azure login every run is reported as `skip`.

### 2. Credential-free harness — `tests/run_validation_tests.sh`

Because a plain `terraform plan` evaluates variable validation *before* configuring the
provider, the entire rejection matrix can be exercised with no Azure account at all. This
script drives `terraform plan` and `terraform console` and asserts on the results:

```bash
bash tests/run_validation_tests.sh
```

42 assertions covering the rejection matrix, the acceptance cases, scope partitioning, name
normalisation, notification/recipient fan-out and ordering independence. Exits non-zero on
any failure.

It also includes a **"Deliberately NOT rejected"** group asserting that inputs the module
should leave alone still pass: a plus-addressed email, a dotted budget key, non-canonical
ARM ID casing, and a notification using only `contact_roles`. That group is the regression
guard against the validation rules drifting over-strict.

### Test matrix coverage

| # | Case | Where |
| --- | --- | --- |
| 1 | One subscription budget | both layers |
| 2 | One resource group budget | both layers |
| 3 | One management group budget | both layers |
| 4 | Multiple resource groups, same subscription | both layers |
| 5 | One budget, one notification | `notifications.tftest.hcl` |
| 6 | One budget, multiple notifications | both layers |
| 7 | One notification, multiple emails | both layers |
| 8 | Multiple notifications, multiple emails | `notifications.tftest.hcl` |
| 9 | Multiple budgets, different scopes | both layers |
| 10 | Budget without notifications | both layers — **asserted to be rejected**; the provider requires at least one |
| 11 | Invalid `scope_type` | both layers |
| 12 | RG scope without `resource_group_id` | both layers |
| 13 | Subscription scope without `subscription_id` | both layers |
| 14 | MG scope without `management_group_id` | both layers |
| 15 | Conflicting scope IDs on one budget | both layers |
| 16 | Map reordering does not change addresses | both layers |

---

## Code quality and Trunk

The module ships a [`.tflint.hcl`](.tflint.hcl). Trunk runs `tflint` as its Terraform
linter and tflint reads the nearest `.tflint.hcl`, so the same file configures both. It is
also usable standalone:

```bash
tflint --init && tflint --recursive
```

### Suggested Trunk linters

Add to your `.trunk/trunk.yaml` at the repository root:

```yaml
lint:
  enabled:
    - terraform        # terraform fmt / validate
    - tflint
    - checkov          # or trivy
    - markdownlint
    - shellcheck       # tests/run_validation_tests.sh
    - shfmt
    - gitleaks
```

### One intentional rule exception

`terraform_standard_module_structure` expects a `main.tf` in the module root. This module
has none on purpose: the three budget scopes map to three distinct Terraform resource
types, and each lives in its own file so a scope-specific schema difference is visible
where it applies rather than buried in one large file. Terraform loads every `.tf` file in
a directory identically, so the split costs nothing at runtime.

The rule is disabled in `.tflint.hcl` with that reasoning recorded inline. If you would
rather satisfy it than disable it, move the contents of `locals.tf` into a new `main.tf`
and delete `locals.tf` — the scope-partitioning locals are a reasonable primary entrypoint.

### What was actually run

| Check | Result |
| --- | --- |
| `terraform fmt -recursive -check` | Clean across module, examples and tests |
| `terraform validate` | Passes for the module and all four examples |
| `bash tests/run_validation_tests.sh` | 42 assertions pass |
| `terraform test` | 31 runs load without error; all skip for lack of Azure credentials |
| tflint `recommended` preset | Hand-checked — no `deprecated_index`, `deprecated_interpolation`, `empty_list_equality`, `unused_declarations`, or missing `required_version` / `required_providers` |
| `tflint` / `checkov` / `trivy` / `terraform-docs` | **Not run** — not installed in this environment |
| Trunk CLI | **Not run** — not installed, and it does not run natively on Windows (needs WSL, macOS or Linux) |
