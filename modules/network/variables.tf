variable "name_base" {
  type        = string
  description = "Name prefix, e.g. slz-dev."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "hub_resource_group_name" {
  type        = string
  description = "Resource group for the hub VNET and Bastion."
}

variable "workload_resource_group" {
  type        = string
  description = "Resource group for the spoke VNETs."
}

variable "hub_address_space" {
  type        = string
  description = "Hub VNET CIDR."
}

variable "spoke_app_address_space" {
  type        = string
  description = "App spoke VNET CIDR."
}

variable "spoke_mgmt_address_space" {
  type        = string
  description = "Mgmt spoke VNET CIDR."
}

variable "allowed_http_source" {
  type        = string
  description = "Service tag or CIDR allowed to reach port 80 on the web tier."
}

variable "enable_bastion" {
  type        = bool
  description = "Deploy Azure Bastion Basic."
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Deploy a NAT gateway for web/db outbound."
}

variable "enable_route_tables" {
  type        = bool
  description = "Create spoke route tables pointing to an NVA."
}

variable "firewall_private_ip" {
  type        = string
  description = "Next-hop IP for the optional route tables."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
}
