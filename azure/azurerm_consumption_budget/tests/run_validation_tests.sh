#!/usr/bin/env bash
###############################################################################
# tests/run_validation_tests.sh
#
# Credential-free test harness.
#
# `terraform test` configures every provider before running any test, and the
# azurerm provider cannot configure without Azure credentials -- so under
# `terraform test` every run is SKIPPED on a machine with no Azure login.
#
# A plain `terraform plan`, by contrast, evaluates variable validation BEFORE
# configuring the provider. That is what this harness drives, so the whole
# validation matrix runs with no Azure account. Routing and normalisation are
# checked with `terraform console`, which needs no provider either.
#
# Usage:  bash tests/run_validation_tests.sh
# Exit 0 = all assertions passed.
###############################################################################

set -uo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES="$(mktemp -d)"
trap 'rm -rf "$FIXTURES"' EXIT

cd "$MODULE_DIR" || exit 1

PASS=0
FAIL=0

# Terraform hard-wraps diagnostics to the terminal width, so a phrase can be
# split across lines. Flatten before matching or a line-based grep misses it.
flatten() { tr '\n' ' ' | tr -s ' '; }

# reject <name> <fixture> <expected message fragment>
reject() {
  local name="$1" file="$2" expect="$3"
  local out
  out="$(terraform plan -no-color -input=false -var-file="$file" 2>&1 | flatten)"

  if grep -qF "$expect" <<<"$out"; then
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name"
    echo "        expected to find: $expect"
    fold -w 100 -s <<<"$out" | sed -n '1,20p' | sed 's/^/          /'
    FAIL=$((FAIL + 1))
  fi
}

# accept <name> <fixture>
# Asserts the fixture passes variable validation. The plan still fails on
# provider configuration (no credentials), which is expected and ignored.
accept() {
  local name="$1" file="$2"
  local out
  out="$(terraform plan -no-color -input=false -var-file="$file" 2>&1 | flatten)"

  if grep -qF "Invalid value for variable" <<<"$out"; then
    echo "  FAIL  $name (unexpected validation rejection)"
    fold -w 100 -s <<<"$out" | grep -A4 "Invalid value for variable" | sed 's/^/          /'
    FAIL=$((FAIL + 1))
  else
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  fi
}

# evaluates <name> <fixture> <expression> <expected>
evaluates() {
  local name="$1" file="$2" expr="$3" expect="$4"
  local out
  out="$(echo "$expr" | terraform console -var-file="$file" 2>/dev/null | tr -d ' \n\r')"

  if [[ "$out" == "$expect" ]]; then
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name"
    echo "        expression: $expr"
    echo "        expected:   $expect"
    echo "        actual:     $out"
    FAIL=$((FAIL + 1))
  fi
}

SUB="/subscriptions/00000000-0000-0000-0000-000000000000"
RG="$SUB/resourceGroups"
MG="/providers/Microsoft.Management/managementGroups/mg-root"
NOTIF='{"w":{"threshold":50,"contact_emails":["a@example.com"]}}'
TP='{"start_date":"2026-10-01T00:00:00Z"}'

fixture() {
  cat >"$FIXTURES/$1" <<JSON
{"budgets": $2}
JSON
  echo "$FIXTURES/$1"
}

echo
echo "==========================================================="
echo " Credential-free validation matrix"
echo "==========================================================="
echo
echo "-- Scope routing rules (module-only concerns) --------------"

reject "Test 11  invalid scope_type" \
  "$(fixture t11.json "{\"bad\":{\"scope_type\":\"rg\",\"subscription_id\":\"$SUB\",\"amount\":100,\"time_period\":$TP,\"notifications\":$NOTIF}}")" \
  "Invalid scope_type on budget(s)"

reject "Test 12  resource_group scope with no resource_group_id" \
  "$(fixture t12.json "{\"openai\":{\"scope_type\":\"resource_group\",\"amount\":100,\"time_period\":$TP,\"notifications\":$NOTIF}}")" \
  "exactly the one scope ID matching its scope_type"

reject "Test 13  subscription scope with no subscription_id" \
  "$(fixture t13.json "{\"platform\":{\"scope_type\":\"subscription\",\"amount\":100,\"time_period\":$TP,\"notifications\":$NOTIF}}")" \
  "exactly the one scope ID matching its scope_type"

reject "Test 13b subscription scope carrying only a management_group_id" \
  "$(fixture t13b.json "{\"platform\":{\"scope_type\":\"subscription\",\"management_group_id\":\"$MG\",\"amount\":100,\"time_period\":$TP,\"notifications\":$NOTIF}}")" \
  "exactly the one scope ID matching its scope_type"

reject "Test 14  management_group scope with no management_group_id" \
  "$(fixture t14.json "{\"enterprise\":{\"scope_type\":\"management_group\",\"amount\":100,\"time_period\":$TP,\"notifications\":$NOTIF}}")" \
  "exactly the one scope ID matching its scope_type"

reject "Test 15  two scope IDs on one budget" \
  "$(fixture t15.json "{\"confused\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"subscription_id\":\"$SUB\",\"amount\":100,\"time_period\":$TP,\"notifications\":$NOTIF}}")" \
  "exactly the one scope ID matching its scope_type"

echo
echo "-- Silent-drop guard at management group scope -------------"

reject "         contact_roles at management group scope" \
  "$(fixture mgroles.json "{\"e\":{\"scope_type\":\"management_group\",\"management_group_id\":\"$MG\",\"amount\":100,\"time_period\":$TP,\"notifications\":{\"w\":{\"threshold\":50,\"contact_emails\":[\"a@example.com\"],\"contact_roles\":[\"Owner\"]}}}}")" \
  "would be silently ignored"

reject "         contact_groups at management group scope" \
  "$(fixture mggroups.json "{\"e\":{\"scope_type\":\"management_group\",\"management_group_id\":\"$MG\",\"amount\":100,\"time_period\":$TP,\"notifications\":{\"w\":{\"threshold\":50,\"contact_emails\":[\"a@example.com\"],\"contact_groups\":[\"$RG/rg-ops/providers/microsoft.insights/actionGroups/ag\"]}}}}")" \
  "would be silently ignored"

echo
echo "-- Provider enums and ranges (invisible to validate) -------"
# for_each hides these values from the provider ValidateFuncs, so without
# these rules they would only fail on a credentialed plan.

reject "Test 10  budget with zero notifications" \
  "$(fixture t10.json "{\"svc\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-svc\",\"amount\":100,\"time_period\":$TP,\"notifications\":{}}}")" \
  "have no notifications"

reject "         amount below 1" \
  "$(fixture amt.json "{\"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":0,\"time_period\":$TP,\"notifications\":$NOTIF}}")" \
  "amount must be >= 1"

reject "         invalid time_grain" \
  "$(fixture tg.json "{\"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":100,\"time_grain\":\"Weekly\",\"time_period\":$TP,\"notifications\":$NOTIF}}")" \
  "Invalid time_grain on budget(s)"

reject "         threshold above 1000" \
  "$(fixture thr.json "{\"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":100,\"time_period\":$TP,\"notifications\":{\"w\":{\"threshold\":1001,\"contact_emails\":[\"a@example.com\"]}}}}")" \
  "threshold must be a whole number between 0 and 1000"

reject "         fractional threshold (provider TypeInt)" \
  "$(fixture thrf.json "{\"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":100,\"time_period\":$TP,\"notifications\":{\"w\":{\"threshold\":80.5,\"contact_emails\":[\"a@example.com\"]}}}}")" \
  "threshold must be a whole number between 0 and 1000"

reject "         invalid notification operator" \
  "$(fixture op.json "{\"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":100,\"time_period\":$TP,\"notifications\":{\"w\":{\"threshold\":50,\"operator\":\"LessThan\",\"contact_emails\":[\"a@example.com\"]}}}}")" \
  "Invalid notification operator(s)"

reject "         invalid threshold_type" \
  "$(fixture tt.json "{\"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":100,\"time_period\":$TP,\"notifications\":{\"w\":{\"threshold\":50,\"threshold_type\":\"Predicted\",\"contact_emails\":[\"a@example.com\"]}}}}")" \
  "Invalid threshold_type(s)"

reject "         notification with no recipients" \
  "$(fixture norecip.json "{\"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":100,\"time_period\":$TP,\"notifications\":{\"w\":{\"threshold\":50}}}}")" \
  "needs at least one recipient"

reject "         management group notification with no contact_emails" \
  "$(fixture mgnoemail.json "{\"e\":{\"scope_type\":\"management_group\",\"management_group_id\":\"$MG\",\"amount\":100,\"time_period\":$TP,\"notifications\":{\"w\":{\"threshold\":50}}}}")" \
  "needs at least one recipient"

reject "         invalid filter dimension name" \
  "$(fixture fd.json "{\"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":100,\"time_period\":$TP,\"notifications\":$NOTIF,\"filter\":{\"dimension\":[{\"name\":\"NotADimension\",\"values\":[\"x\"]}]}}}")" \
  "Invalid filter dimension name"

reject "         filter operator other than In" \
  "$(fixture fo.json "{\"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":100,\"time_period\":$TP,\"notifications\":$NOTIF,\"filter\":{\"tag\":[{\"name\":\"env\",\"operator\":\"NotIn\",\"values\":[\"prod\"]}]}}}")" \
  "accept only \"In\""

reject "         empty filter block" \
  "$(fixture fe.json "{\"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":100,\"time_period\":$TP,\"notifications\":$NOTIF,\"filter\":{}}}")" \
  "at least one dimension or tag"

echo
echo "-- Deliberately NOT rejected (delegated to provider/Azure) --"
# These rules were removed on purpose: enforcing them here risks rejecting
# input the provider would accept. The module must let them through.

accept "         unusual but valid email (plus-addressing, .co.uk)" \
  "$(fixture plus.json "{\"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":100,\"time_period\":$TP,\"notifications\":{\"w\":{\"threshold\":50,\"contact_emails\":[\"finops+azure@example.co.uk\"]}}}}")"

accept "         budget key with a dot (valid for_each key)" \
  "$(fixture dotkey.json "{\"team.openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":100,\"time_period\":$TP,\"notifications\":$NOTIF}}")"

accept "         uppercase resourceGroups segment in the ARM ID" \
  "$(fixture caseid.json "{\"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$SUB/RESOURCEGROUPS/rg-openai\",\"amount\":100,\"time_period\":$TP,\"notifications\":$NOTIF}}")"

accept "         contact_roles only, no emails (valid at RG scope)" \
  "$(fixture roles.json "{\"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":100,\"time_period\":$TP,\"notifications\":{\"w\":{\"threshold\":50,\"contact_roles\":[\"Owner\"]}}}}")"

accept "         threshold at both boundaries (0 and 1000)" \
  "$(fixture bound.json "{\"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":1,\"time_period\":$TP,\"notifications\":{\"lo\":{\"threshold\":0,\"contact_emails\":[\"a@example.com\"]},\"hi\":{\"threshold\":1000,\"contact_emails\":[\"a@example.com\"]}}}}")"

echo
echo "-- Acceptance cases ----------------------------------------"

MIXED="{
  \"platform\":{\"scope_type\":\"subscription\",\"subscription_id\":\"$SUB\",\"amount\":5000,\"time_period\":$TP,\"notifications\":{\"warning\":{\"threshold\":50,\"contact_emails\":[\"a@example.com\"]},\"critical\":{\"threshold\":90,\"contact_emails\":[\"a@example.com\",\"b@example.com\"],\"contact_roles\":[\"Owner\"]}}},
  \"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":1000,\"time_period\":$TP,\"notifications\":{\"warning\":{\"threshold\":50,\"contact_emails\":[\"a@example.com\",\"b@example.com\",\"c@example.com\"]}}},
  \"azure_foundry\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-azure-foundry\",\"name\":\"budget-azure-foundry\",\"amount\":2000,\"time_period\":$TP,\"notifications\":{\"warning\":{\"threshold\":50,\"contact_emails\":[\"a@example.com\"]}},\"filter\":{\"tag\":[{\"name\":\"costCenter\",\"values\":[\"cc-1\"]}]}},
  \"enterprise\":{\"scope_type\":\"management_group\",\"management_group_id\":\"$MG\",\"amount\":50000,\"time_period\":$TP,\"notifications\":{\"warning\":{\"threshold\":75,\"contact_emails\":[\"a@example.com\"]}}}
}"
MIXED_FILE="$(fixture mixed.json "$MIXED")"

MIXED_REORDERED="{
  \"enterprise\":{\"scope_type\":\"management_group\",\"management_group_id\":\"$MG\",\"amount\":50000,\"time_period\":$TP,\"notifications\":{\"warning\":{\"threshold\":75,\"contact_emails\":[\"a@example.com\"]}}},
  \"azure_foundry\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-azure-foundry\",\"name\":\"budget-azure-foundry\",\"amount\":2000,\"time_period\":$TP,\"notifications\":{\"warning\":{\"threshold\":50,\"contact_emails\":[\"a@example.com\"]}},\"filter\":{\"tag\":[{\"name\":\"costCenter\",\"values\":[\"cc-1\"]}]}},
  \"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":1000,\"time_period\":$TP,\"notifications\":{\"warning\":{\"threshold\":50,\"contact_emails\":[\"a@example.com\",\"b@example.com\",\"c@example.com\"]}}},
  \"platform\":{\"scope_type\":\"subscription\",\"subscription_id\":\"$SUB\",\"amount\":5000,\"time_period\":$TP,\"notifications\":{\"warning\":{\"threshold\":50,\"contact_emails\":[\"a@example.com\"]},\"critical\":{\"threshold\":90,\"contact_emails\":[\"a@example.com\",\"b@example.com\"],\"contact_roles\":[\"Owner\"]}}}
}"
REORDERED_FILE="$(fixture mixed_reordered.json "$MIXED_REORDERED")"

accept "Test 9   mixed scopes in one invocation" "$MIXED_FILE"
accept "Test 16  the same budgets written in reverse order" "$REORDERED_FILE"

accept "Test 1   one subscription budget" \
  "$(fixture a1.json "{\"platform\":{\"scope_type\":\"subscription\",\"subscription_id\":\"$SUB\",\"amount\":5000,\"time_period\":$TP,\"notifications\":$NOTIF}}")"

accept "Test 2   one resource group budget" \
  "$(fixture a2.json "{\"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":1000,\"time_period\":$TP,\"notifications\":$NOTIF}}")"

accept "Test 3   one management group budget" \
  "$(fixture a3.json "{\"enterprise\":{\"scope_type\":\"management_group\",\"management_group_id\":\"$MG\",\"amount\":50000,\"time_period\":$TP,\"notifications\":$NOTIF}}")"

accept "Test 4   three resource groups in one subscription" \
  "$(fixture a4.json "{
    \"openai\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-openai\",\"amount\":1000,\"time_period\":$TP,\"notifications\":$NOTIF},
    \"azure_foundry\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-azure-foundry\",\"amount\":2000,\"time_period\":$TP,\"notifications\":$NOTIF},
    \"another_service\":{\"scope_type\":\"resource_group\",\"resource_group_id\":\"$RG/rg-another-service\",\"amount\":500,\"time_period\":$TP,\"notifications\":$NOTIF}
  }")"

echo
echo "-- Scope routing and normalisation (terraform console) ------"

evaluates "Test 1-3 subscription partition holds only the subscription budget" \
  "$MIXED_FILE" 'keys(local.subscription_budgets)' '["platform",]'

evaluates "Test 4   resource group partition holds both RG budgets" \
  "$MIXED_FILE" 'keys(local.resource_group_budgets)' '["azure_foundry","openai",]'

evaluates "Test 3   management group partition holds only the MG budget" \
  "$MIXED_FILE" 'keys(local.management_group_budgets)' '["enterprise",]'

evaluates "Test 9   every budget is routed to exactly one partition" \
  "$MIXED_FILE" \
  'length(local.subscription_budgets) + length(local.resource_group_budgets) + length(local.management_group_budgets) == length(var.budgets)' \
  'true'

evaluates "Test 16  reversing the source order yields identical partitions" \
  "$REORDERED_FILE" 'keys(local.resource_group_budgets)' '["azure_foundry","openai",]'

evaluates "Test 16  reversing the source order keeps values bound to keys" \
  "$REORDERED_FILE" 'local.resource_group_budgets["openai"].amount' '1000'

evaluates "         name falls back to the map key when omitted" \
  "$MIXED_FILE" 'local.budget_names["openai"]' '"openai"'

evaluates "         an explicit name wins over the map key" \
  "$MIXED_FILE" 'local.budget_names["azure_foundry"]' '"budget-azure-foundry"'

evaluates "Test 6   multiple notifications survive on one budget" \
  "$MIXED_FILE" 'length(var.budgets["platform"].notifications)' '2'

evaluates "Test 7   multiple email recipients survive on one notification" \
  "$MIXED_FILE" 'length(var.budgets["openai"].notifications["warning"].contact_emails)' '3'

evaluates "         defaults applied to omitted notification fields" \
  "$MIXED_FILE" \
  'var.budgets["openai"].notifications["warning"].operator == "GreaterThan" && var.budgets["openai"].notifications["warning"].threshold_type == "Actual" && var.budgets["openai"].notifications["warning"].enabled' \
  'true'

echo
echo "==========================================================="
printf " %d passed, %d failed\n" "$PASS" "$FAIL"
echo "==========================================================="
echo

[[ "$FAIL" -eq 0 ]]
