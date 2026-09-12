# Example — Subscription budget

The simplest case: one budget scoped to an entire subscription.

## What it shows

- `scope_type = "subscription"` with `subscription_id`
- A single notification at 80% of actual spend
- Provider configuration living in the **root** module, not in the reusable module

## Note on `subscription_id`

azurerm 4.x validates this with `commonids.ValidateSubscriptionID`, which requires the
**full resource ID**:

```hcl
subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"   # correct
subscription_id = "00000000-0000-0000-0000-000000000000"                  # rejected
```

Older registry documentation mentions a bare GUID being acceptable; that note is stale for
the 4.x provider. The module rejects the bare form with an explicit message.

## Usage

```bash
terraform init
terraform plan  -var 'subscription_guid=00000000-0000-0000-0000-000000000000'
terraform apply -var 'subscription_guid=00000000-0000-0000-0000-000000000000'
```

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `subscription_guid` | `string` | — | Bare subscription GUID. Used both to configure the provider and to build the scope ID |
| `budget_start_date` | `string` | `2026-10-01T00:00:00Z` | RFC3339, must be the first of a month |
| `budget_contact_emails` | `list(string)` | `["owner@example.com"]` | Notification recipients |

## Outputs

| Name | Description |
| --- | --- |
| `budget_ids` | Logical budget key → Azure budget resource ID |
