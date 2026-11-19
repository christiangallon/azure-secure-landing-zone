# ---------------------------------------------------------------------------
# Subscription / naming
# ---------------------------------------------------------------------------
variable "subscription_id" {
  description = "Azure subscription ID to deploy into. Leave null to use ARM_SUBSCRIPTION_ID."
  type        = string
  default     = null
}

variable "tenant_id" {
  description = "Entra ID tenant ID. Leave null to use ARM_TENANT_ID / Azure CLI context."
  type        = string
  default     = null
}

variable "prefix" {
  description = "Short prefix used in all resource names (lowercase letters/numbers, 2-8 chars)."
  type        = string
  default     = "slz"

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.prefix))
    error_message = "prefix must be 2-8 lowercase letters or numbers."
  }
}

variable "environment" {
  description = "Environment name (dev, test, prod)."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus"
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------
variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "christian-gallon"
}

variable "cost_center" {
  description = "Cost-center tag value."
  type        = string
  default     = "portfolio-lab"
}

variable "extra_tags" {
  description = "Additional tags merged into every resource."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
variable "hub_address_space" {
  description = "Hub VNET CIDR."
  type        = string
  default     = "10.0.0.0/16"
}

variable "spoke_app_address_space" {
  description = "Application spoke VNET CIDR (web + db subnets)."
  type        = string
  default     = "10.1.0.0/16"
}

variable "spoke_mgmt_address_space" {
  description = "Management spoke VNET CIDR (ops tooling subnet)."
  type        = string
  default     = "10.2.0.0/16"
}

variable "allowed_http_source" {
  description = "Source allowed to reach the web tier on port 80 via the public load balancer: a service tag (Internet) or one CIDR. Narrow to your own IP (x.x.x.x/32) for the lab."
  type        = string
  default     = "Internet"
}

variable "enable_bastion" {
  description = "Deploy Azure Bastion (Basic). COST: ~$0.19/hr + public IP while it exists. Destroy after every session."
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Deploy a NAT gateway for outbound internet (package installs) from web/db subnets. COST: ~$0.045/hr + data."
  type        = bool
  default     = true
}

variable "enable_route_tables" {
  description = "Create spoke route tables forcing 0.0.0.0/0 to an NVA/firewall IP (only useful once a firewall exists)."
  type        = bool
  default     = false
}

variable "firewall_private_ip" {
  description = "Next-hop IP for the optional spoke route tables."
  type        = string
  default     = "10.0.3.4"
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------
variable "admin_username" {
  description = "Linux admin username on all VMs."
  type        = string
  default     = "azureadmin"
}

variable "admin_ssh_public_key" {
  description = "SSH public key (OpenSSH format) for the VM admin user. Password auth is disabled."
  type        = string
}

variable "web_vm_count" {
  description = "Number of web VMs behind the load balancer (1 = cheapest, 2 = redundant web tier)."
  type        = number
  default     = 1

  validation {
    condition     = var.web_vm_count >= 1 && var.web_vm_count <= 3
    error_message = "web_vm_count must be between 1 and 3."
  }
}

variable "web_vm_size" {
  description = "Web VM size."
  type        = string
  default     = "Standard_B1s"
}

variable "db_vm_size" {
  description = "Database VM size."
  type        = string
  default     = "Standard_B2s"
}

variable "auto_shutdown_time" {
  description = "Daily VM auto-shutdown time (HHMM, 24h)."
  type        = string
  default     = "1900"
}

variable "auto_shutdown_timezone" {
  description = "Windows timezone ID for auto-shutdown."
  type        = string
  default     = "Eastern Standard Time"
}

# ---------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------
variable "key_vault_purge_protection" {
  description = "Enable purge protection on Key Vault. Recommended for prod; leave false in the lab so names can be reused after destroy."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Monitoring / alerting
# ---------------------------------------------------------------------------
variable "alert_email" {
  description = "Email address for the alert action group and budget notifications."
  type        = string
}

variable "log_analytics_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 30
}

variable "log_analytics_daily_quota_gb" {
  description = "Daily ingestion cap (GB) for Log Analytics - cost guardrail. -1 = unlimited."
  type        = number
  default     = 1
}

variable "enable_entra_diagnostics" {
  description = "Stream Entra ID SignInLogs/AuditLogs to Log Analytics (requires Entra ID P1/P2 and Global/Security Administrator). Needed for the sign-in and PIM alert rules."
  type        = bool
  default     = true
}

variable "enable_logic_app" {
  description = "Deploy a Logic App that forwards alerts to a chat webhook (Teams/Slack). Requires notification_webhook_url."
  type        = bool
  default     = false
}

variable "notification_webhook_url" {
  description = "Incoming webhook URL (Teams/Slack) used by the Logic App. Never commit this - pass via TF_VAR_notification_webhook_url."
  type        = string
  default     = ""
  sensitive   = true
}

variable "budget_amount" {
  description = "Monthly subscription budget (USD) for cost alerts."
  type        = number
  default     = 50
}

# ---------------------------------------------------------------------------
# Defender for Cloud
# ---------------------------------------------------------------------------
variable "enable_defender_paid_plans" {
  description = "Turn on paid Defender for Cloud plans (Servers P1, Storage, Key Vault). COST - off by default; free foundational CSPM is always on."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Identity (Entra ID)
# ---------------------------------------------------------------------------
variable "enable_identity_module" {
  description = "Deploy Entra ID objects (named location, Conditional Access, PIM). Requires Graph permissions - see docs/SETUP.md."
  type        = bool
  default     = true
}

variable "trusted_ip_ranges" {
  description = "CIDRs treated as the trusted named location (e.g. your home/office public IP as x.x.x.x/32)."
  type        = list(string)
  default     = []
}

variable "ca_enforce" {
  description = "false = Conditional Access policies in report-only mode (default). true = enforce."
  type        = bool
  default     = false
}

variable "break_glass_object_ids" {
  description = "Object IDs of emergency-access accounts excluded from Conditional Access."
  type        = list(string)
  default     = []
}

variable "enable_pim" {
  description = "Create a PIM eligible assignment for pim_principal_object_id (requires Entra ID P2)."
  type        = bool
  default     = false
}

variable "pim_principal_object_id" {
  description = "Object ID of the user/group that becomes ELIGIBLE (not active) for pim_role_name."
  type        = string
  default     = ""
}

variable "pim_role_name" {
  description = "Entra directory role made eligible through PIM."
  type        = string
  default     = "Security Administrator"
}
