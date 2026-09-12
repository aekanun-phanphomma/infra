# Example — One $100 budget for Azure OpenAI + AI Foundry across two resource groups

## The scenario

```text
subscription
  |
  +-- rg-ai-one ---- Azure OpenAI account       -> resource ID 1
  |                  Azure AI Foundry account   -> resource ID 2
  |
  +-- rg-ai-two ---- Azure OpenAI account       -> resource ID 3
                     Azure AI Foundry account   -> resource ID 4
```

Four resource IDs, two resource groups, one subscription. One shared **$100** limit. When
actual spend across all four passes $100, **two people** get an email.

## Why subscription scope and not two resource group budgets

A resource group budget cannot span two resource groups. Using them here would mean two
separate $100 limits — **$200 of total exposure**, with neither alert aware of the other.

A single subscription-scoped budget gives one shared $100 ceiling. The `ResourceId` filter
then narrows it to exactly the four AI accounts, so unrelated spend elsewhere in the
subscription does not consume the budget.

## The four resource IDs

Supply them in `var.ai_resource_ids` as full ARM resource IDs:

```hcl
filter = {
  dimension = [
    {
      name   = "ResourceId"
      values = var.ai_resource_ids
    },
  ]
}
```

`ResourceId` is one of the 24 dimension names the provider accepts, and the values are your
own resource IDs — nothing depends on guessing Azure billing meter names.

### Getting the IDs

```bash
az resource list \
  --resource-type Microsoft.CognitiveServices/accounts \
  --query "[].{name:name, rg:resourceGroup, id:id}" -o table
```

Or in the portal: open each account, then **Properties → Resource ID**.

Azure OpenAI and Azure AI Foundry accounts are both
`Microsoft.CognitiveServices/accounts` resources, differing only by `kind` (`OpenAI` vs
`AIServices`). **Hub-based** Azure AI Foundry is different — it is a
`Microsoft.MachineLearningServices/workspaces` resource. Pasting the real IDs rather than
assembling them from parts means either kind works without changing the code.

### No default, on purpose

`ai_resource_ids` is a required variable. A placeholder ID would match nothing and the
budget would sit silently at zero while spend ran unchecked — the worst failure mode for a
cost guardrail. Terraform will make you supply real values.

> **Verify the ID casing after the first apply.** Azure Cost Management is commonly reported
> to normalise resource IDs to lowercase in cost data, and the filter matches on exact
> values. Open **Cost analysis**, group by **Resource**, and confirm the budget is
> accumulating spend. If it stays at zero while the accounts are clearly being used,
> lowercase the values in `ai_resource_ids` and re-apply.

## The alert

```hcl
notifications = {
  exceeded = {
    threshold      = 100          # percent of `amount`, so 100% of $100
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.budget_contact_emails   # two recipients
  }
}
```

`threshold` is a **percentage of `amount`**, not a currency figure. With `amount = 100` and
`threshold = 100`, the alert fires once actual spend exceeds $100.

### Optional: get warned before you hit the limit

This alerts only after the $100 is already spent. AI workloads can spike quickly, so you
may want an earlier signal. Add either of these to the `notifications` map — the map keys
are Terraform-side labels, so adding one does not disturb the existing alert:

```hcl
# 80% of the budget, actual spend
warning = {
  threshold      = 80
  operator       = "GreaterThan"
  contact_emails = var.budget_contact_emails
}

# Azure forecasts you will exceed the budget this period
forecast = {
  threshold      = 100
  operator       = "GreaterThan"
  threshold_type = "Forecasted"
  contact_emails = var.budget_contact_emails
}
```

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your four resource IDs and two email addresses

terraform init
terraform plan
terraform apply
```

Confirm what the filter will match before applying:

```bash
terraform console <<< 'var.ai_resource_ids'
```

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `subscription_guid` | `string` | — | Bare subscription GUID holding both resource groups |
| `ai_resource_ids` | `list(string)` | — **required** | The four full resource IDs the budget counts |
| `budget_amount` | `number` | `100` | Budget amount in the billing currency |
| `budget_contact_emails` | `list(string)` | two example addresses | Alert recipients |
| `budget_start_date` | `string` | `2026-10-01T00:00:00Z` | RFC3339, must be the first of a month |

`ai_resource_ids` is validated to be non-empty, free of blank entries, and free of
duplicates. Its *format* is deliberately left to Azure — see
[Validation rules](../../README.md#validation-rules) for why this module does not regex ARM
IDs.

## Outputs

| Name | Description |
| --- | --- |
| `budget_ids` | Logical budget key → Azure budget resource ID |
| `filtered_resource_ids` | The resource IDs the budget counts — compare against Cost analysis |

## Permissions

Creating this budget needs **Cost Management Contributor** (or Owner/Contributor) on the
subscription. No extra role is needed here because the alert uses email only — routing to
an Action Group would additionally require **Monitoring Reader**.

Note that on a brand-new subscription it can take **up to 48 hours** before budgets can be
created at all.
