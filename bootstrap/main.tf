# -----------------------------------------------------------------------------
# Bootstrap: creates the remote-state storage for the main configuration.
# Run ONCE, locally, with your own Azure CLI login. Uses LOCAL state (this
# folder's terraform.tfstate is git-ignored). Keep it - do not destroy it
# between lab sessions; it costs cents per month.
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  subscription_id     = var.subscription_id
  storage_use_azuread = true
  features {}
}

variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "State resource group name."
  type        = string
  default     = "rg-slz-tfstate"
}

variable "github_principal_object_id" {
  description = "Object ID of the GitHub Actions service principal (Enterprise application). Granted Storage Blob Data Contributor on the state account. Leave empty to skip."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags for state resources."
  type        = map(string)
  default = {
    project       = "azure-secure-landing-zone"
    owner         = "christian-gallon"
    env           = "shared"
    "cost-center" = "portfolio-lab"
    managed-by    = "terraform-bootstrap"
  }
}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "state" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "state" {
  #checkov:skip=CKV_AZURE_59:State account must be reachable by GitHub-hosted runners; mitigated by shared_access_key_enabled=false (Entra ID auth only) + RBAC. Prod: private endpoint + self-hosted runners.
  #checkov:skip=CKV2_AZURE_33:Same as CKV_AZURE_59 - no private endpoint so hosted runners can reach state.
  #checkov:skip=CKV_AZURE_206:LRS acceptable for a lab; blob versioning + 30-day soft delete protect state. Prod: ZRS/GRS.
  #checkov:skip=CKV2_AZURE_1:Microsoft-managed keys acceptable for lab; CMK documented under At Production Scale.
  #checkov:skip=CKV_AZURE_33:Queue service is not used.
  name                            = "sttfstate${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false # Entra ID auth only (use_azuread_auth = true)
  default_to_oauth_authentication = true
  tags                            = var.tags

  lifecycle {
    prevent_destroy = true
  }

  blob_properties {
    versioning_enabled = true # every state write is a recoverable version

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }
}

resource "azurerm_storage_container" "tfstate" {
  #checkov:skip=CKV2_AZURE_21:Lab state account; blob logging not configured to avoid a Log Analytics dependency in bootstrap.
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

# Prevent accidental deletion of the state account.
resource "azurerm_management_lock" "state" {
  name       = "lock-tfstate"
  scope      = azurerm_storage_account.state.id
  lock_level = "CanNotDelete"
  notes      = "Terraform remote state - do not delete."
}

# Data-plane access for you (local runs) and for the GitHub OIDC identity.
resource "azurerm_role_assignment" "me" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "github" {
  count = var.github_principal_object_id != "" ? 1 : 0

  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.github_principal_object_id
  principal_type       = "ServicePrincipal"
}

output "backend_hcl" {
  description = "Paste into ../backend.hcl (git-ignored)."
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.state.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name       = "${azurerm_storage_container.tfstate.name}"
    key                  = "azure-secure-landing-zone/dev.tfstate"
    use_azuread_auth     = true
  EOT
}

output "storage_account_name" {
  description = "State storage account name (set as GitHub variable TF_STATE_STORAGE_ACCOUNT)."
  value       = azurerm_storage_account.state.name
}

output "resource_group_name" {
  description = "State resource group (set as GitHub variable TF_STATE_RESOURCE_GROUP)."
  value       = azurerm_resource_group.state.name
}
