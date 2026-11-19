# Identity: what Terraform does vs. manual portal steps

Some Entra ID features have limited or no Terraform support. This page lists exactly what the code manages and what you configure by hand (and screenshot as evidence).

## Managed by Terraform (`modules/identity`)

| Item | Resource |
|---|---|
| Trusted named location (your IPs) | `azuread_named_location` |
| CA pilot security group | `azuread_group` |
| CA01: require MFA outside the trusted location (report-only by default) | `azuread_conditional_access_policy` |
| CA02: block legacy authentication (report-only by default) | `azuread_conditional_access_policy` |
| PIM **eligible** assignment of `pim_role_name` to `pim_principal_object_id` | `azuread_directory_role_eligibility_schedule_request` |
| Entra sign-in/audit logs → Log Analytics | `azurerm_monitor_aad_diagnostic_setting` (monitoring module) |

## Manual (portal) — not supported by the azuread provider

### PIM role settings for the eligible role
Portal → **Entra ID → Identity Governance → Privileged Identity Management → Microsoft Entra roles → Settings → `Security Administrator` → Edit**
- Activation maximum duration: **1–2 hours**
- On activation, require: **Azure MFA** ✔, **Justification** ✔, optionally **Ticket information**
- Require approval to activate: optional (add yourself or a second account as approver)
- Assignment tab: eligible assignments expire after **30 days** (or less), and don't allow permanent active assignment
- Notification tab: send an email on activation to your alert address

### Break-glass account
- Create a cloud-only account (e.g. `breakglass@<tenant>.onmicrosoft.com`) with a long random password stored offline, and assign it Global Administrator
- Put its object ID in `break_glass_object_ids` so every CA policy excludes it

### Pilot users
- Add your test user(s) to the `grp-slz-dev-ca-pilot` group (Terraform outputs its object ID)

### If you chose Option B in SETUP (CI kept out of Entra ID)
Create the same objects by hand, using the names above:
1. Named location (**Entra ID → Protection → Conditional Access → Named locations**)
2. CA01 and CA02 in **Report-only** state
3. PIM eligible assignment (**PIM → Microsoft Entra roles → Assignments → Add assignments → Eligible**)
4. Diagnostic setting (**Entra ID → Monitoring → Diagnostic settings → Add**: SignInLogs, AuditLogs → your Log Analytics workspace)

## Licensing
- Conditional Access and sign-in logs in Log Analytics: **Entra ID P1** (included in P2)
- PIM: **Entra ID P2** (30-day trial available)
