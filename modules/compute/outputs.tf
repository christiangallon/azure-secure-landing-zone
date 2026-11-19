output "load_balancer_id" {
  description = "Load balancer ID."
  value       = azurerm_lb.web.id
}

output "load_balancer_public_ip" {
  description = "Load balancer public IP."
  value       = azurerm_public_ip.lb.ip_address
}

output "web_vm_private_ips" {
  description = "Web VM private IPs."
  value       = azurerm_network_interface.web[*].private_ip_address
}

output "db_vm_private_ip" {
  description = "DB VM private IP."
  value       = azurerm_network_interface.db.private_ip_address
}

output "web_vm_principal_ids" {
  description = "System-assigned managed identity principal IDs of the web VMs."
  value       = azurerm_linux_virtual_machine.web[*].identity[0].principal_id
}
