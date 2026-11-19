resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# Storage account: no public network access, no shared keys, TLS 1.2+, versioning.
resource "azurerm_storage_account" "this" {
  #checkov:skip=CKV_AZURE_206:LRS acceptable for lab data; ZRS/GRS documented under At Production Scale.
  #checkov:skip=CKV2_AZURE_1:Microsoft-managed keys + infrastructure encryption for lab; CMK documented under At Production Scale.
  #checkov:skip=CKV_AZURE_33:Queue service is not used.
  name                              = substr("st${var.prefix}${random_string.suffix.result}", 0, 24)
  resource_group_name               = var.resource_group_name
  location                          = var.location
  account_tier                      = "Standard"
  account_replication_type          = "LRS" # ZRS/GRS at production scale
  account_kind                      = "StorageV2"
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  public_network_access_enabled     = false
  allow_nested_items_to_be_public   = false
  shared_access_key_enabled         = false # Entra ID (RBAC) auth only
  default_to_oauth_authentication   = true
  infrastructure_encryption_enabled = true
  tags                              = var.tags

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices", "Logging", "Metrics"]
  }
}

# Created through the ARM control plane (storage_account_id), so it works even
# though the data plane is private-only.
resource "azurerm_storage_container" "app" {
  #checkov:skip=CKV2_AZURE_21:Blob read/write/delete logging is configured in modules/monitoring (azurerm_monitor_diagnostic_setting.blob); Checkov cannot see across modules.
  name                  = "app-data"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

# ---------------------------------------------------------------------------
# Private DNS + private endpoint
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  for_each = var.vnet_ids

  name                  = "link-blob-${each.key}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = each.value
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${var.name_base}-blob"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.name_base}-blob"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}
