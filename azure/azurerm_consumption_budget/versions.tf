# >= 1.6.0: optional() attribute defaults and expressions in validation
# error_message need 1.3; the native `terraform test` framework needs 1.6.
#
# ~> 4.0: implemented against the azurerm 4.81.0 schema. 4.x is stable for
# these three resources; 5.x may rename or remove arguments.
#
# No provider block here on purpose -- a reusable module inherits the provider
# configured by its caller.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
