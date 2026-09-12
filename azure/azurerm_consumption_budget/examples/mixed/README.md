# Example — Mixed scopes in one invocation

The point of this module: **four budgets across three different Azure scopes, from one
`module` block.**

```text
Budget A  platform        ->  subscription
Budget B  openai          ->  resource group
Budget C  azure_foundry   ->  resource group
Budget D  enterprise      ->  management group
```

## What it shows

- `scope_type` as a **per-budget** decision, not a module-level one
- Terraform creating **three different resource types** from a single module call
- The management group budget using only `contact_emails`, while the subscription budget
  also uses `contact_roles` — the provider schema difference, expressed naturally
- Per-budget `time_grain` (`Quarterly` on `azure_foundry`, `Monthly` elsewhere)
- A tag filter on one budget only
- Unified outputs keyed by logical name, plus `budget_ids_by_scope` for when you do need to
  tell scopes apart

## Resulting Terraform addresses

```text
module.consumption_budgets.azurerm_consumption_budget_subscription.this["platform"]
module.consumption_budgets.azurerm_consumption_budget_resource_group.this["openai"]
module.consumption_budgets.azurerm_consumption_budget_resource_group.this["azure_foundry"]
module.consumption_budgets.azurerm_consumption_budget_management_group.this["enterprise"]
```

Every instance key is the logical budget key. There is no `[0]`, `[1]`, `[2]` anywhere, so
reordering the map in source has no effect on state.

## Outputs

`budget_ids` flattens all four into one map keyed by logical name:

```hcl
{
  platform      = "/subscriptions/.../providers/Microsoft.Consumption/budgets/budget-platform"
  openai        = "/subscriptions/.../resourceGroups/rg-openai/providers/Microsoft.Consumption/budgets/budget-openai"
  azure_foundry = "/subscriptions/.../resourceGroups/rg-azure-foundry/providers/Microsoft.Consumption/budgets/budget-azure-foundry"
  enterprise    = "/providers/Microsoft.Management/managementGroups/.../providers/Microsoft.Consumption/budgets/budget-enterprise"
}
```

`budget_ids_by_scope` groups the same IDs under `subscription`, `resource_group` and
`management_group`, and `budget_scope_types` tells you which resource type — and therefore
which `terraform import` command — applies to each key.

## Careful: changing a budget's scope

Moving `openai` from `resource_group` to `subscription` is **not** an in-place update. It
changes the Terraform resource type, so Terraform plans a destroy and a create. See
[Scope migration warning](../../README.md#scope-migration-warning) in the module README.

## Usage

```bash
terraform init
terraform plan \
  -var 'subscription_guid=00000000-0000-0000-0000-000000000000' \
  -var 'management_group_name=mg-root'
```

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `subscription_guid` | `string` | — | Subscription hosting the subscription budget and both resource groups |
| `management_group_name` | `string` | — | Management group name (resource ID segment) |
| `budget_start_date` | `string` | `2026-10-01T00:00:00Z` | RFC3339, first of a month; applied to all four budgets |

## Outputs

| Name | Description |
| --- | --- |
| `budget_ids` | All four budgets, keyed by logical name |
| `budget_ids_by_scope` | The same IDs grouped by scope type |
| `budget_scope_types` | Which scope each logical key was routed to |
