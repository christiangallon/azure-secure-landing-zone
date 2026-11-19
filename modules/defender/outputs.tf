output "enabled_plans" {
  description = "Paid Defender plans enabled by this module."
  value       = keys(local.paid_plans)
}
