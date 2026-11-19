output "storage_account_id" {
  description = "Storage account ID."
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "Storage account name."
  value       = azurerm_storage_account.this.name
}

output "private_dns_zone_id" {
  description = "privatelink.blob.core.windows.net zone ID."
  value       = azurerm_private_dns_zone.blob.id
}
