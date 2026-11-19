terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Partial backend configuration. Values are supplied at init time:
  #   terraform init -backend-config=backend.hcl
  # See backend.hcl.example and bootstrap/ (which creates the state storage).
  backend "azurerm" {}
}

provider "azurerm" {
  # Locally: set via terraform.tfvars or ARM_SUBSCRIPTION_ID.
  # CI: ARM_SUBSCRIPTION_ID is exported from the AZURE_SUBSCRIPTION_ID secret.
  subscription_id = var.subscription_id

  # Use Entra ID (not shared keys) for storage data-plane calls.
  storage_use_azuread = true

  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      # Lab setting so "terraform destroy" never gets stuck on leftovers.
      prevent_deletion_if_contains_resources = false
    }
    storage {
      # Storage is private-endpoint only; CI runners cannot reach the data
      # plane, so manage everything through the ARM control plane.
      data_plane_available = false
    }
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }
}

provider "azuread" {
  tenant_id = var.tenant_id
}
