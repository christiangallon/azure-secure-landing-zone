output "resource_groups" {
  description = "Resource groups created by this deployment."
  value = {
    hub      = azurerm_resource_group.hub.name
    workload = azurerm_resource_group.workload.name
    secops   = azurerm_resource_group.secops.name
  }
}

output "load_balancer_public_ip" {
  description = "Public IP of the web load balancer (http://<ip>/)."
  value       = module.compute.load_balancer_public_ip
}

output "web_vm_private_ips" {
  description = "Private IPs of the web VMs."
  value       = module.compute.web_vm_private_ips
}

output "db_vm_private_ip" {
  description = "Private IP of the DB VM (reachable only from the web subnet and Bastion)."
  value       = module.compute.db_vm_private_ip
}

output "bastion_name" {
  description = "Azure Bastion host name (null when disabled)."
  value       = module.network.bastion_name
}

output "storage_account_name" {
  description = "Storage account name (public network access disabled)."
  value       = module.storage.storage_account_name
}

output "key_vault_uri" {
  description = "Key Vault URI (private endpoint only)."
  value       = module.keyvault.key_vault_uri
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = module.monitoring.workspace_id
}

output "alert_rule_names" {
  description = "Scheduled query alert rules."
  value       = module.monitoring.alert_rule_names
}

output "conditional_access_state" {
  description = "Conditional Access policy state (report-only unless ca_enforce = true)."
  value       = var.enable_identity_module ? module.identity[0].conditional_access_state : "identity module disabled"
}
