## Summary
<!-- What does this change and why? -->

## Change type
- [ ] Network
- [ ] Compute
- [ ] Storage / Key Vault
- [ ] Monitoring / KQL
- [ ] Identity (Conditional Access / PIM)
- [ ] CI/CD
- [ ] Docs only

## Checklist
- [ ] `terraform fmt -recursive` run locally
- [ ] `terraform validate` passes
- [ ] Plan reviewed (see bot comment) - no unexpected destroys/replacements
- [ ] Checkov/TFLint findings fixed or justified with an inline skip + reason
- [ ] No secrets, tfvars, or state files committed
- [ ] Cost impact considered (Bastion / NAT / Defender toggles)
- [ ] Conditional Access changes stay report-only unless intentionally enforcing

## Risk / rollback
<!-- What could break? How do we roll back? -->
