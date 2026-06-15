###############################################################################
# identity.tf — the identity Velero authenticates as.
#
# A user-assigned managed identity plus a federated identity credential that
# trusts tokens issued by the cluster's OIDC issuer for the Velero service
# account. With this in place the Velero pods exchange their projected service
# account token for an Entra token — no client secret or storage key on disk.
###############################################################################

resource "azurerm_user_assigned_identity" "velero" {
  name                = "id-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "velero" {
  name      = "fc-${var.name_prefix}"
  parent_id = azurerm_user_assigned_identity.velero.id
  audience  = var.federated_credential_audience
  issuer    = var.oidc_issuer_url
  subject   = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
}
