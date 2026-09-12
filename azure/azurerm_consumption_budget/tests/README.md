# Tests

Two complementary layers, because one of them cannot run without an Azure account and the
other can.

---

## Layer 1 — native Terraform tests (`*.tftest.hcl`)

The canonical suite: **31 `run` blocks**, all `command = plan`. Nothing is created in Azure.

| File | Runs | Matrix coverage |
| --- | --- | --- |
| `scopes.tftest.hcl` | 6 | Tests 1, 2, 3, 4, 9, 16 — scope routing, per-instance isolation, name fallback, address stability |
| `notifications.tftest.hcl` | 7 | Tests 5, 6, 7, 8 — notification fan-out, multi-recipient handling, filters, management group reduced schema |
| `validation.tftest.hcl` | 15 | Tests 10–15 and the remaining rejection rules, plus one run asserting permissive-but-valid input is not rejected |

```bash
cd ..            # the module root
terraform test
```

### This layer needs Azure credentials

`terraform test` configures **every provider before it executes any run block**. The
azurerm provider cannot configure without a valid Azure login, so on a machine with no
credentials the whole suite reports:

```text
Failure! 0 passed, 0 failed, 31 skipped.
Error: unable to build authorizer for Resource Manager API: ...
```

That is an environment result, not a module defect — but it does mean the pure
input-validation cases, which never need to talk to Azure, cannot run here either. Hence
layer 2.

To run this layer, authenticate first (any azurerm-supported method):

```bash
az login
terraform test
```

---

## Layer 2 — credential-free harness (`run_validation_tests.sh`)

A plain `terraform plan` evaluates **variable validation before configuring the provider**,
and reports both problems. So the entire validation matrix can be exercised with no Azure
account at all.

```bash
bash tests/run_validation_tests.sh
```

**42 assertions**, exits non-zero on any failure:

| Group | Count | What it does |
| --- | --- | --- |
| Scope routing rules | 6 | Module-only concerns the provider can never check |
| Silent-drop guard | 2 | `contact_groups` / `contact_roles` at management group scope |
| Provider enums and ranges | 13 | Values `for_each` hides from the provider's own `ValidateFunc`s |
| Deliberately NOT rejected | 5 | Inputs the module must leave alone — the over-strictness guard |
| Acceptance cases | 6 | Whole configurations that must pass validation cleanly |
| Routing / normalisation | 10 | `terraform console` on `local.*` — partitioning, name fallback, ordering independence |

### Why "Deliberately NOT rejected" exists

The module used to validate email format, Action Group ID shape, ARM ID shape, budget key
format and `start_date` date arithmetic. Those were removed: each encoded an *interpretation*
of a rule the provider states differently, so a wrong guess would reject configurations
Azure accepts. That is a worse failure than the one it prevents.

This group pins the decision down with cases that must keep passing:

- `finops+azure@example.co.uk` — plus-addressing and a two-part TLD
- `team.openai` — a budget key containing a dot
- `/subscriptions/.../RESOURCEGROUPS/rg-openai` — non-canonical ARM ID casing
- a notification with `contact_roles` only and no `contact_emails`

### Two implementation details worth knowing

- **Message matching is wrap-aware.** Terraform hard-wraps diagnostics to the terminal
  width, so a phrase can be split across lines. The harness flattens output to a single
  line before matching; a naive line-based `grep` silently misses these.
- **`terraform console` needs no provider.** It evaluates locals directly, which is how
  scope partitioning and address stability get checked without an Azure login.

---

## Full matrix

| # | Case | Layer 1 | Layer 2 |
| --- | --- | --- | --- |
| 1 | One subscription budget | yes | yes |
| 2 | One resource group budget | yes | yes |
| 3 | One management group budget | yes | yes |
| 4 | Multiple resource groups, same subscription | yes | yes |
| 5 | One budget, one notification | yes | — |
| 6 | One budget, multiple notifications | yes | yes |
| 7 | One notification, multiple emails | yes | yes |
| 8 | Multiple notifications, multiple emails | yes | — |
| 9 | Multiple budgets, different scopes | yes | yes |
| 10 | Budget without notifications | yes (rejected) | yes (rejected) |
| 11 | Invalid `scope_type` | yes | yes |
| 12 | RG scope without `resource_group_id` | yes | yes |
| 13 | Subscription scope without `subscription_id` | yes | yes |
| 14 | MG scope without `management_group_id` | yes | yes |
| 15 | Conflicting scope IDs | yes | yes |
| 16 | Reordering does not change addresses | yes | yes |

### On Test 10

"A budget without notifications" is **not a supported configuration**. The provider
declares the `notification` block as `Required` with `MinItems: 1` on all three budget
resources, so Azure has no such thing as a notification-less budget. Both layers therefore
assert that the module *rejects* it, with a message explaining the provider constraint.

### On Test 15

A literally duplicated map key (`openai = {...}` twice) is a **HCL parse error**, caught by
Terraform before any module code runs — there is nothing for a module to validate. The
equivalent case a module *can* catch is a single budget carrying more than one scope ID, so
that is what is tested.

---

## Static analysis

The module ships a [`.tflint.hcl`](../.tflint.hcl), which both standalone `tflint` and
Trunk's tflint linter will pick up.

`tflint`, `checkov`, `trivy` and `terraform-docs` were not installed in the environment
this module was developed in, so they were **not** run here. The module was instead
hand-checked against tflint's `recommended` preset; see the Trunk section of the module
[README](../README.md#code-quality-and-trunk).
