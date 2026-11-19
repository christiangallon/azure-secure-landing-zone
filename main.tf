data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

locals {
  name_base = "${var.prefix}-${var.environment}"

  tags = merge({
    project       = "azure-secure-landing-zone"
    owner         = var.owner
    env           = var.environment
    "cost-center" = var.cost_center
    managed-by    = "terraform"
  }, var.extra_tags)
}

# ---------------------------------------------------------------------------
# Resource groups - split by function so RBAC and lifecycle can differ.
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "hub" {
  name     = "rg-${local.name_base}-hub"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "workload" {
  name     = "rg-${local.name_base}-workload"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "secops" {
  name     = "rg-${local.name_base}-secops"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Modules
# ---------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  name_base                = local.name_base
  location                 = var.location
  hub_resource_group_name  = azurerm_resource_group.hub.name
  workload_resource_group  = azurerm_resource_group.workload.name
  hub_address_space        = var.hub_address_space
  spoke_app_address_space  = var.spoke_app_address_space
  spoke_mgmt_address_space = var.spoke_mgmt_address_space
  allowed_http_source      = var.allowed_http_source
  enable_bastion           = var.enable_bastion
  enable_nat_gateway       = var.enable_nat_gateway
  enable_route_tables      = var.enable_route_tables
  firewall_private_ip      = var.firewall_private_ip
  tags                     = local.tags
}

module "storage" {
  source = "./modules/storage"

  name_base                  = local.name_base
  prefix                     = var.prefix
  location                   = var.location
  resource_group_name        = azurerm_resource_group.workload.name
  private_endpoint_subnet_id = module.network.privatelink_subnet_id
  vnet_ids                   = module.network.all_vnet_ids
  tags                       = local.tags
}

module "keyvault" {
  source = "./modules/keyvault"

  name_base                  = local.name_base
  prefix                     = var.prefix
  location                   = var.location
  resource_group_name        = azurerm_resource_group.secops.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  private_endpoint_subnet_id = module.network.privatelink_subnet_id
  vnet_ids                   = module.network.all_vnet_ids
  purge_protection_enabled   = var.key_vault_purge_protection
  tags                       = local.tags
}

module "compute" {
  source = "./modules/compute"

  name_base              = local.name_base
  location               = var.location
  resource_group_name    = azurerm_resource_group.workload.name
  web_subnet_id          = module.network.web_subnet_id
  db_subnet_id           = module.network.db_subnet_id
  web_vm_count           = var.web_vm_count
  web_vm_size            = var.web_vm_size
  db_vm_size             = var.db_vm_size
  admin_username         = var.admin_username
  admin_ssh_public_key   = var.admin_ssh_public_key
  web_subnet_cidr        = module.network.web_subnet_cidr
  storage_account_id     = module.storage.storage_account_id
  key_vault_id           = module.keyvault.key_vault_id
  auto_shutdown_time     = var.auto_shutdown_time
  auto_shutdown_timezone = var.auto_shutdown_timezone
  tags                   = local.tags
}

module "monitoring" {
  source = "./modules/monitoring"

  name_base                = local.name_base
  location                 = var.location
  resource_group_name      = azurerm_resource_group.secops.name
  subscription_id          = data.azurerm_subscription.current.id
  retention_days           = var.log_analytics_retention_days
  daily_quota_gb           = var.log_analytics_daily_quota_gb
  alert_email              = var.alert_email
  enable_entra_diagnostics = var.enable_entra_diagnostics
  enable_logic_app         = var.enable_logic_app
  notification_webhook_url = var.notification_webhook_url
  budget_amount            = var.budget_amount
  storage_account_id       = module.storage.storage_account_id
  key_vault_id             = module.keyvault.key_vault_id
  load_balancer_id         = module.compute.load_balancer_id
  nsg_ids                  = module.network.nsg_ids
  tags                     = local.tags
}

module "defender" {
  source = "./modules/defender"

  enable_paid_plans = var.enable_defender_paid_plans
}

module "identity" {
  source = "./modules/identity"
  count  = var.enable_identity_module ? 1 : 0

  name_base               = local.name_base
  trusted_ip_ranges       = var.trusted_ip_ranges
  ca_enforce              = var.ca_enforce
  break_glass_object_ids  = var.break_glass_object_ids
  enable_pim              = var.enable_pim
  pim_principal_object_id = var.pim_principal_object_id
  pim_role_name           = var.pim_role_name
}
