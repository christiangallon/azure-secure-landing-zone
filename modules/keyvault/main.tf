resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

# Key Vault (Standard): RBAC authorization, private endpoint only.
resource "azurerm_key_vault" "this" {
  #checkov:skip=CKV_AZURE_110:Purge protection is a variable (key_vault_purge_protection); off in the lab so the vault can be destroyed each session. Set true for prod.
  #checkov:skip=CKV_AZURE_42:Soft delete (7 days) is always on; full recoverability needs purge protection - see CKV_AZURE_110.
  name                          = substr("kv-${var.prefix}-${random_string.suffix.result}", 0, 24)
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  soft_delete_retention_days    = 7
  purge_protection_enabled      = var.purge_protection_enabled
  public_network_access_enabled = false
  tags                          = var.tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

resource "azurerm_private_dns_zone" "vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "vault" {
  for_each = var.vnet_ids

  name                  = "link-vault-${each.key}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.vault.name
  virtual_network_id    = each.value
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "vault" {
  name                = "pe-${var.name_base}-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.name_base}-kv"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "vault-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.vault.id]
  }
}
