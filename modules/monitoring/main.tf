# ---------------------------------------------------------------------------
# Log Analytics workspace
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "this" {
  name                = "law-${var.name_base}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days
  daily_quota_gb      = var.daily_quota_gb
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Diagnostic settings -> Log Analytics
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "diag-activity-to-law"
  target_resource_id         = var.subscription_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log { category = "Administrative" }
  enabled_log { category = "Security" }
  enabled_log { category = "Policy" }
  enabled_log { category = "Alert" }
}

resource "azurerm_monitor_diagnostic_setting" "blob" {
  name                       = "diag-blob-to-law"
  target_resource_id         = "${var.storage_account_id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log { category = "StorageRead" }
  enabled_log { category = "StorageWrite" }
  enabled_log { category = "StorageDelete" }

  enabled_metric { category = "Transaction" }
}

resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "diag-kv-to-law"
  target_resource_id         = var.key_vault_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log { category_group = "audit" }

  enabled_metric { category = "AllMetrics" }
}

resource "azurerm_monitor_diagnostic_setting" "nsg" {
  for_each = var.nsg_ids

  name                       = "diag-nsg-to-law"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log { category = "NetworkSecurityGroupEvent" }
  enabled_log { category = "NetworkSecurityGroupRuleCounter" }
}

resource "azurerm_monitor_diagnostic_setting" "lb" {
  name                       = "diag-lb-to-law"
  target_resource_id         = var.load_balancer_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_metric { category = "AllMetrics" }
}

# Entra ID sign-in + audit logs (tenant-level). Requires Entra ID P1/P2 and
# Global Administrator or Security Administrator for the identity running apply.
resource "azurerm_monitor_aad_diagnostic_setting" "entra" {
  count = var.enable_entra_diagnostics ? 1 : 0

  name                       = "diag-entra-to-law-${var.name_base}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log { category = "SignInLogs" }
  enabled_log { category = "AuditLogs" }
  enabled_log { category = "NonInteractiveUserSignInLogs" }
  enabled_log { category = "RiskyUsers" }
}

# ---------------------------------------------------------------------------
# Notification: optional Logic App (chat webhook) + action group (email)
# ---------------------------------------------------------------------------
resource "azurerm_logic_app_workflow" "notify" {
  count = var.enable_logic_app ? 1 : 0

  name                = "logic-${var.name_base}-alert-notify"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_logic_app_trigger_http_request" "alert" {
  count = var.enable_logic_app ? 1 : 0

  name         = "azure-monitor-alert"
  logic_app_id = azurerm_logic_app_workflow.notify[0].id
  schema       = "{}"
}

resource "azurerm_logic_app_action_http" "post_webhook" {
  count = var.enable_logic_app ? 1 : 0

  name         = "post-to-chat"
  logic_app_id = azurerm_logic_app_workflow.notify[0].id
  method       = "POST"
  uri          = var.notification_webhook_url
  headers      = { "Content-Type" = "application/json" }
  body = jsonencode({
    text = "Azure alert fired: @{triggerBody()?['data']?['essentials']?['alertRule']} | severity @{triggerBody()?['data']?['essentials']?['severity']} | state @{triggerBody()?['data']?['essentials']?['monitorCondition']}"
  })

  depends_on = [azurerm_logic_app_trigger_http_request.alert]
}

resource "azurerm_monitor_action_group" "security" {
  name                = "ag-${var.name_base}-security"
  resource_group_name = var.resource_group_name
  short_name          = "secalerts"
  tags                = var.tags

  email_receiver {
    name                    = "security-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }

  dynamic "logic_app_receiver" {
    for_each = var.enable_logic_app ? [1] : []
    content {
      name                    = "logic-app-notify"
      resource_id             = azurerm_logic_app_workflow.notify[0].id
      callback_url            = azurerm_logic_app_trigger_http_request.alert[0].callback_url
      use_common_alert_schema = true
    }
  }
}

# ---------------------------------------------------------------------------
# KQL scheduled query alert rules (queries live in /kql)
# ---------------------------------------------------------------------------
locals {
  kql_dir = "${path.module}/../../kql"

  alert_rules = {
    failed-signins-same-ip = {
      display_name = "Entra ID: 5+ failed sign-ins from same IP in 10 min"
      description  = "Possible brute force / password spray (MITRE T1110)."
      query_file   = "failed_signins_same_ip.kql"
      severity     = 1
      window       = "PT10M"
    }
    pim-admin-role-activation = {
      display_name = "Entra ID: PIM admin role activated"
      description  = "A privileged directory role was activated through PIM (MITRE T1078.004)."
      query_file   = "pim_admin_role_activation.kql"
      severity     = 2
      window       = "PT15M"
    }
    storage-access-public-ip = {
      display_name = "Storage: blob access from public IP"
      description  = "Request to the private-only storage account from a non-RFC1918 address (MITRE T1530)."
      query_file   = "storage_access_public_ip.kql"
      severity     = 1
      window       = "PT15M"
    }
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "this" {
  for_each = local.alert_rules

  name                    = "alert-${var.name_base}-${each.key}"
  display_name            = each.value.display_name
  description             = each.value.description
  resource_group_name     = var.resource_group_name
  location                = var.location
  scopes                  = [azurerm_log_analytics_workspace.this.id]
  severity                = each.value.severity
  evaluation_frequency    = "PT5M"
  window_duration         = each.value.window
  enabled                 = true
  auto_mitigation_enabled = false
  # Entra tables (SigninLogs/AuditLogs) do not exist until data has flowed.
  skip_query_validation = true
  tags                  = var.tags

  criteria {
    query                   = file("${local.kql_dir}/${each.value.query_file}")
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.security.id]
  }
}

# ---------------------------------------------------------------------------
# Budget alert (cost guardrail)
# ---------------------------------------------------------------------------
resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "budget-${var.name_base}-monthly"
  subscription_id = var.subscription_id
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      enabled        = true
      threshold      = notification.value
      operator       = "GreaterThanOrEqualTo"
      threshold_type = "Actual"
      contact_emails = [var.alert_email]
    }
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Forecasted"
    contact_emails = [var.alert_email]
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}
