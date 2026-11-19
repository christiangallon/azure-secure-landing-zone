variable "name_base" {
  type        = string
  description = "Name prefix, e.g. slz-dev."
}

variable "prefix" {
  type        = string
  description = "Short prefix for globally-unique names."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for Key Vault."
}

variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID."
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet ID for the private endpoint."
}

variable "vnet_ids" {
  type        = map(string)
  description = "VNETs to link to the private DNS zone."
}

variable "purge_protection_enabled" {
  type        = bool
  description = "Enable purge protection."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
}
