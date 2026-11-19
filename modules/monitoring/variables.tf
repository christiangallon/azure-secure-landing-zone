variable "name_base" {
  type        = string
  description = "Name prefix, e.g. slz-dev."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for monitoring resources."
}

variable "subscription_id" {
  type        = string
  description = "Subscription resource ID (/subscriptions/<id>) for activity log + budget."
}

variable "retention_days" {
  type        = number
  description = "Log Analytics retention."
}

variable "daily_quota_gb" {
  type        = number
  description = "Log Analytics daily ingestion cap (GB)."
}

variable "alert_email" {
  type        = string
  description = "Alert/budget email recipient."
}

variable "enable_entra_diagnostics" {
  type        = bool
  description = "Stream Entra sign-in/audit logs to the workspace."
}

variable "enable_logic_app" {
  type        = bool
  description = "Deploy the Logic App notifier."
}

variable "notification_webhook_url" {
  type        = string
  description = "Chat webhook URL for the Logic App."
  sensitive   = true
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget amount."
}

variable "storage_account_id" {
  type        = string
  description = "Storage account ID (blob diagnostics)."
}

variable "key_vault_id" {
  type        = string
  description = "Key Vault ID (audit diagnostics)."
}

variable "load_balancer_id" {
  type        = string
  description = "Load balancer ID (metrics)."
}

variable "nsg_ids" {
  type        = map(string)
  description = "NSG IDs to send diagnostics for."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
}
