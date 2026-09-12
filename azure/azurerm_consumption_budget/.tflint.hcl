# tflint configuration for this module.
#
# Trunk runs tflint as its Terraform linter, and tflint reads the nearest
# .tflint.hcl, so this file configures both. It is also usable standalone:
#   tflint --init && tflint --recursive

config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# The azurerm ruleset catches provider-specific mistakes (invalid values,
# deprecated arguments). Enable if you want deeper checks; it requires
# `tflint --init` to download the plugin.
#
# plugin "azurerm" {
#   enabled = true
#   version = "0.27.0"
#   source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
# }

# This module deliberately has no main.tf.
#
# The three budget scopes map to three distinct Terraform resource types, and
# each lives in its own file (subscription.tf, resource_group.tf,
# management_group.tf) so that a scope-specific schema difference is visible
# where it applies rather than buried in a single large file. Terraform loads
# every .tf file in a directory identically, so the split is purely for
# maintainability.
#
# terraform_standard_module_structure would otherwise flag the missing main.tf.
# If you would rather satisfy the rule than disable it, move the contents of
# locals.tf into a new main.tf and delete locals.tf -- the scope-partitioning
# locals are a reasonable "primary entrypoint" for this module.
rule "terraform_standard_module_structure" {
  enabled = false
}
