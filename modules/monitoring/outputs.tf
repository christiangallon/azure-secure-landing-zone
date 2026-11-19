output "workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = azurerm_log_analytics_workspace.this.id
}

output "action_group_id" {
  description = "Security action group ID."
  value       = azurerm_monitor_action_group.security.id
}

output "alert_rule_names" {
  description = "Names of the KQL scheduled query alert rules."
  value       = [for r in azurerm_monitor_scheduled_query_rules_alert_v2.this : r.name]
}
