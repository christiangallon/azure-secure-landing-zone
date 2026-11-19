# 30-day deploy window plan

The free Azure account gives **$200 for 30 days**, and the **Entra ID P2 trial lasts 30 days**. Both clocks start when you activate them. So the plan is: do everything that costs nothing *first*, then use the 30 days only for deploying, testing and capturing evidence.

## Golden rule: destroy every session

> Every session ends with `terraform destroy` (or the `terraform-destroy` workflow), and then you check the portal shows no `rg-slz-dev-*` resource groups. Bastion alone is ~$0.19/hr (~$4.50/day) if forgotten. Only `bootstrap/` (state storage, cents per month) stays up.

Session checklist:
1. `terraform apply` (or merge a PR → approve)
2. Test + screenshot (save to `docs/images/evidence/`, and tick the README Evidence box only for what you captured)
3. `terraform destroy`
4. Portal → Cost Management → check today's spend

---

## Phase 0 — before starting any trial (cost: $0)

- [ ] Read through every module and understand each resource (interview prep)
- [ ] Install Azure CLI, push the repo to GitHub ([SETUP.md](SETUP.md) steps 1–3)
- [ ] `terraform init -backend=false && terraform validate` locally
- [ ] Open a test PR and confirm the **static checks** job runs green (no Azure needed)
- [ ] Fill in `terraform.tfvars` (except IDs you don't have yet)
- [ ] Draft the README sections you can write now (problem, decisions)
- [ ] Decide trial timing: put the 30 days on a stretch with enough free evenings and weekends

> `terraform plan` against Azure needs a subscription. If you already have any Azure subscription (even pay-as-you-go with a budget), you can run `plan` there for free. Plans don't create resources.

## Week 1 — account, state, network + compute

- [ ] Activate the Azure free account. Set a **budget alert** in the portal right away as a backstop.
- [ ] SETUP steps 4–7: az login, OIDC app + federated credentials, roles, GitHub secrets/vars, `production` environment, bootstrap state
- [ ] Local `terraform plan`, then first apply with `enable_identity_module = false`, `enable_entra_diagnostics = false`
- [ ] Verify: peering Connected, NSG effective rules, Bastion SSH into the web VM, `curl` the LB IP, DB port only reachable from web, private DNS resolves storage to 10.0.2.x
- [ ] Screenshots → destroy

## Week 2 — CI/CD pipeline

- [ ] Branch protection on `main` (require PR + checks)
- [ ] Feature branch → PR → **plan comment posted** → merge → **approval gate** → apply
- [ ] Run the `terraform-destroy` workflow once (confirmation input + approval)
- [ ] Deliberately introduce a Checkov finding in a PR and screenshot the failed check, then fix it
- [ ] Screenshots of each pipeline stage → destroy

## Week 3 — monitoring + KQL

- [ ] Apply with monitoring (always on) and optionally `enable_logic_app = true` with a Teams/Slack webhook in the `TFVARS` secret
- [ ] Generate test signal:
  - Storage: from your laptop, run `az storage blob list --account-name <sa> --auth-mode login` → it gets denied (public IP) and shows up in `StorageBlobLogs`
  - Run each `.kql` file in Log Analytics and screenshot the results
- [ ] Confirm alert email (and chat message) for the storage rule
- [ ] Screenshot Defender for Cloud secure score (free tier) → destroy

## Week 4 — identity (start the Entra ID P2 trial here, or at the start of week 3)

- [ ] Activate the **Entra ID P2 trial**. Create a **break-glass** account and a test user.
- [ ] Grant Graph permissions (SETUP Option A) or follow the manual steps (Option B)
- [ ] Apply with `enable_identity_module = true`, `enable_entra_diagnostics = true`, `enable_pim = true`
- [ ] Add the test user to the CA pilot group, sign in from outside the trusted IP (e.g. phone on cellular), and screenshot the **report-only** result in sign-in logs
- [ ] Configure PIM role settings in the portal ([IDENTITY_MANUAL_STEPS.md](IDENTITY_MANUAL_STEPS.md)), activate the role, and screenshot the PIM alert firing
- [ ] Generate 5+ failed sign-ins for the test user from one IP and screenshot alert #1
- [ ] Optionally flip `ca_enforce = true` for the pilot group and screenshot the MFA prompt
- [ ] Destroy

## Final days — evidence, README, LinkedIn

- [ ] Tick only the Evidence boxes you actually captured, and embed the screenshots
- [ ] Change the README status line to "Deployed and torn down — evidence captured <date>"
- [ ] Final `terraform destroy`. Check the portal is empty except `rg-slz-tfstate`.
- [ ] LinkedIn post series (draft ahead, publish once evidence exists):
  1. The problem + architecture diagram
  2. Zero-trust identity: CA report-only → enforce, PIM JIT
  3. KQL detections, with real alert screenshots
  4. OIDC pipeline: plan-on-PR, approval gate, no secrets
  5. Cost discipline: what it actually cost and how teardown worked
- [ ] Optionally cancel/downgrade before the trial converts to pay-as-you-go

---

### Rough cost estimate for the window

About 20 sessions × ~3 hrs with Bastion + NAT + LB + 2 small VMs comes to roughly **$0.30/hr → ~$18–25 total**, well inside the $200 credit. That holds *only* if you destroy every session. This is an estimate; check Cost Management after the first session and adjust.
