output "hub_vnet_id" {
  description = "Hub VNET ID."
  value       = azurerm_virtual_network.hub.id
}

output "all_vnet_ids" {
  description = "Map of all VNET IDs (for private DNS zone links)."
  value = {
    hub  = azurerm_virtual_network.hub.id
    app  = azurerm_virtual_network.spoke_app.id
    mgmt = azurerm_virtual_network.spoke_mgmt.id
  }
}

output "web_subnet_id" {
  description = "Web subnet ID."
  value       = azurerm_subnet.web.id
}

output "web_subnet_cidr" {
  description = "Web subnet CIDR."
  value       = local.web_cidr
}

output "db_subnet_id" {
  description = "DB subnet ID."
  value       = azurerm_subnet.db.id
}

output "privatelink_subnet_id" {
  description = "Private endpoint subnet ID."
  value       = azurerm_subnet.privatelink.id
}

output "nsg_ids" {
  description = "Map of NSG IDs (for diagnostic settings)."
  value       = { for k, v in local.subnet_nsg : k => v.nsg_id }
}

output "bastion_name" {
  description = "Bastion host name, or null."
  value       = var.enable_bastion ? azurerm_bastion_host.this[0].name : null
}
