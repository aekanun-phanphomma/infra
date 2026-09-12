# Example — Multiple resource group budgets

Three resource groups in the **same subscription**, each with its own independent budget,
created by a **single** module invocation.

## What it shows

- Multiple resource-group-scoped budgets side by side (`openai`, `azure_foundry`,
  `another_service`)
- **Multiple notifications per budget** — 50% warning, 80% critical, 100% exceeded, plus a
  forecast-based alert
- **Multiple email recipients per notification**, differing per threshold
- `contact_roles` and `contact_groups` — both valid at this scope, neither available at
  management group scope
- `threshold_type = "Forecasted"` alongside the default `Actual`
- A `filter` with **two dimensions and one tag**
- An explicit `end_date`

## Resulting Terraform addresses

```text
module.consumption_budgets.azurerm_consumption_budget_resource_group.this["openai"]
module.consumption_budgets.azurerm_consumption_budget_resource_group.this["azure_foundry"]
module.consumption_budgets.azurerm_consumption_budget_resource_group.this["another_service"]
```

Each is a fully independent resource. Removing one from the map affects only that one —
there is no index shifting, because `for_each` keys off the logical name.

## A note on `another_service`

You may see configurations written as:

```hcl
another_service = {
  ...
  notifications = {}     # INVALID
}
```

That cannot work. The provider declares the `notification` block as **Required with
`MinItems: 1`** on all three budget resources, so a budget with zero notifications is not a
valid Azure configuration. This module rejects it at plan time with an explanatory message
rather than letting it fail in the provider. `another_service` therefore carries one
notification.

## Usage

```bash
terraform init
terraform plan -var 'subscription_guid=00000000-0000-0000-0000-000000000000'
```

To route alerts through an Action Group as well as email:

```bash
terraform plan \
  -var 'subscription_guid=00000000-0000-0000-0000-000000000000' \
  -var 'action_group_ids=["/subscriptions/.../resourceGroups/rg-ops/providers/microsoft.insights/actionGroups/ag-finops"]'
```

Using `contact_groups` requires **Monitoring Reader** on the action group in addition to
Cost Management Contributor on the budget scope.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `subscription_guid` | `string` | — | Subscription GUID hosting all three resource groups |
| `budget_start_date` | `string` | `2026-10-01T00:00:00Z` | RFC3339, first of a month |
| `action_group_ids` | `list(string)` | `[]` | Action Group resource IDs for the `azure_foundry` critical alert |

## Outputs

| Name | Description |
| --- | --- |
| `budget_ids` | Logical budget key → Azure budget resource ID |
| `budget_names` | Logical budget key → Azure budget name |
