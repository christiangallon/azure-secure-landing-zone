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
  description = "Resource group for compute resources."
}

variable "web_subnet_id" {
  type        = string
  description = "Web subnet ID."
}

variable "web_subnet_cidr" {
  type        = string
  description = "Web subnet CIDR (allowed in pg_hba.conf on the DB VM)."
}

variable "db_subnet_id" {
  type        = string
  description = "DB subnet ID."
}

variable "web_vm_count" {
  type        = number
  description = "Number of web VMs."
}

variable "web_vm_size" {
  type        = string
  description = "Web VM size."
}

variable "db_vm_size" {
  type        = string
  description = "DB VM size."
}

variable "admin_username" {
  type        = string
  description = "Admin username."
}

variable "admin_ssh_public_key" {
  type        = string
  description = "Admin SSH public key."
}

variable "storage_account_id" {
  type        = string
  description = "Storage account the web VM identity can read."
}

variable "key_vault_id" {
  type        = string
  description = "Key Vault the web VM identity can read secrets from."
}

variable "auto_shutdown_time" {
  type        = string
  description = "Daily shutdown time HHMM."
}

variable "auto_shutdown_timezone" {
  type        = string
  description = "Windows timezone ID."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
}
