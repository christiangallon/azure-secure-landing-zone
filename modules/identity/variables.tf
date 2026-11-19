variable "name_base" {
  type        = string
  description = "Name prefix, e.g. slz-dev."
}

variable "trusted_ip_ranges" {
  type        = list(string)
  description = "Trusted named location CIDRs."
}

variable "ca_enforce" {
  type        = bool
  description = "Enforce CA policies (false = report-only)."
}

variable "break_glass_object_ids" {
  type        = list(string)
  description = "Emergency-access accounts excluded from CA."
}

variable "enable_pim" {
  type        = bool
  description = "Create the PIM eligible assignment."
}

variable "pim_principal_object_id" {
  type        = string
  description = "Principal made eligible for the admin role."

  validation {
    condition     = var.pim_principal_object_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.pim_principal_object_id))
    error_message = "pim_principal_object_id must be empty or a GUID."
  }
}

variable "pim_role_name" {
  type        = string
  description = "Directory role display name."
}
