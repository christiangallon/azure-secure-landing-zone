output "conditional_access_state" {
  description = "State applied to the CA policies."
  value       = local.ca_state
}

output "ca_pilot_group_object_id" {
  description = "Object ID of the CA pilot group - add test users here."
  value       = azuread_group.ca_pilot.object_id
}

output "conditional_access_policy_ids" {
  description = "Conditional Access policy IDs."
  value = [
    azuread_conditional_access_policy.mfa_outside_trusted.id,
    azuread_conditional_access_policy.block_legacy_auth.id,
  ]
}
