# Defender for Cloud.
# Foundational CSPM (secure score + recommendations) is free and always on.
# Paid workload-protection plans are created ONLY when enable_paid_plans = true.
# On destroy, Terraform sets the plan back to the Free tier.
locals {
  paid_plans = var.enable_paid_plans ? {
    VirtualMachines = "P1"                   # Defender for Servers Plan 1
    StorageAccounts = "DefenderForStorageV2" # per-storage-account pricing
    KeyVaults       = "PerKeyVault"
  } : {}
}

resource "azurerm_security_center_subscription_pricing" "this" {
  for_each = local.paid_plans

  tier          = "Standard"
  resource_type = each.key
  subplan       = each.value
}
