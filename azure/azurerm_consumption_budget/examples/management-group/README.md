# Example — Management group budget

A budget scoped to a management group, covering every subscription beneath it.

## What it shows

- `scope_type = "management_group"` with `management_group_id`
- Two notification thresholds, each with multiple email recipients
- The **reduced notification schema** that applies only at this scope

## The management group notification schema is different

This is the one place where the three budget resources genuinely diverge. The provider
overrides the shared notification block for
`azurerm_consumption_budget_management_group`:

| `notification` argument | subscription / resource group | management group |
| --- | --- | --- |
| `contact_emails` | Optional | **Required, min 1** |
| `contact_groups` | Optional | **Does not exist** |
| `contact_roles` | Optional | **Does not exist** |

So this is valid at resource group scope but **rejected** here:

```hcl
notifications = {
  warning = {
    threshold      = 50
    contact_emails = ["a@example.com"]
    contact_roles  = ["Owner"]        # INVALID at management group scope
  }
}
```

The module fails this at plan time with a message explaining why, rather than silently
dropping the argument.

This is an Azure platform constraint, not a provider gap — Microsoft's documentation states
that action groups are only supported for subscription and resource group scopes.

## `management_group_id` format

Use the management group **name** (the resource ID segment), not the display name:

```hcl
management_group_id = "/providers/Microsoft.Management/managementGroups/mg-root"
```

## Single-currency requirement

Budget evaluation requires every subscription under the management group to bill in the
same currency. Mixed-currency scopes may not evaluate, and alerts can be missed.

## Usage

```bash
terraform init
terraform plan \
  -var 'subscription_guid=00000000-0000-0000-0000-000000000000' \
  -var 'management_group_name=mg-root'
```

The `subscription_guid` here only configures the provider; the budget itself is scoped to
the management group.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `subscription_guid` | `string` | — | Subscription GUID used to configure the provider |
| `management_group_name` | `string` | — | Management group name (resource ID segment, not display name) |
| `budget_start_date` | `string` | `2026-10-01T00:00:00Z` | RFC3339, first of a month |

## Outputs

| Name | Description |
| --- | --- |
| `budget_ids` | Logical budget key → Azure budget resource ID |
