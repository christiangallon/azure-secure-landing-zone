# Setup guide (Windows · VS Code · PowerShell / Git Bash)

This guide covers getting the repo onto GitHub and connecting GitHub Actions to Azure with OIDC (no client secrets). Commands are **PowerShell** unless marked *Git Bash*. Replace every `<PLACEHOLDER>`. Never commit real IDs, keys or tfvars.

> Do steps 1–4 any time; they cost nothing. Do steps 5+ only once your Azure account exists. See [DEPLOY_PLAN.md](DEPLOY_PLAN.md) for timing.

---

## 1. Install the tools

```powershell
# Azure CLI
winget install -e --id Microsoft.AzureCLI
# Git (if not already installed) and GitHub CLI (optional, handy)
winget install -e --id Git.Git
winget install -e --id GitHub.cli
# TFLint (optional, for local linting)
winget install -e --id TerraformLinters.tflint
```

Close and reopen VS Code/PowerShell, then check:

```powershell
az version
terraform version   # 1.6+ required (you have 1.17)
git --version
```

Recommended VS Code extensions are listed in `.vscode/extensions.json`. VS Code will offer to install them when you open the folder.

## 2. Create an SSH key (for the VMs)

```powershell
ssh-keygen -t ed25519 -C "azure-slz" -f $HOME\.ssh\azure_slz
Get-Content $HOME\.ssh\azure_slz.pub    # this PUBLIC key goes into tfvars
```

## 3. Put the repo on GitHub

1. In the browser, go to **https://github.com/new**
   - Repository name: `azure-secure-landing-zone`
   - Public (recruiters can see it) or Private
   - **Leave everything unchecked:** no README, no .gitignore, no license. The repo must be empty or the first push will conflict.
   - Click **Create repository**
2. Unzip `azure-secure-landing-zone.zip`, for example to `C:\Users\<YOU>\projects\azure-secure-landing-zone`. The zip includes the `.git` folder with the first commit.
3. Push:

```powershell
cd C:\Users\<YOU>\projects\azure-secure-landing-zone
git status                      # should say: On branch main, nothing to commit
git log --oneline               # shows the initial commit
git remote add origin https://github.com/christiangallon/azure-secure-landing-zone.git
git push -u origin main
```

Git will open a browser window to sign in to GitHub the first time (Git Credential Manager).

> Commits use the identity configured in the zip (`Christian Gallon <christiangallon6@gmail.com>`). To check or set it for future commits: `git config user.name` / `git config user.email`.

## 4. Sign in to Azure

```powershell
az login
az account list -o table
az account set --subscription "<SUBSCRIPTION_ID>"
az account show --query "{sub:id, tenant:tenantId, user:user.name}" -o table
```

Note your `<SUBSCRIPTION_ID>` and `<TENANT_ID>`. **Do not** paste them into any committed file.

---

## 5. Create the GitHub Actions identity (Entra app + OIDC federated credentials)

```powershell
$SUB    = "<SUBSCRIPTION_ID>"
$REPO   = "christiangallon/azure-secure-landing-zone"

# App registration + service principal
$APP_ID = az ad app create --display-name "gh-azure-secure-landing-zone" --query appId -o tsv
az ad sp create --id $APP_ID
$SP_OBJECT_ID = az ad sp show --id $APP_ID --query id -o tsv
$TENANT = az account show --query tenantId -o tsv
"APP_ID=$APP_ID  SP_OBJECT_ID=$SP_OBJECT_ID  TENANT=$TENANT"
```

Create three federated credentials, one per workflow context. Subjects must match exactly (no wildcards):

```powershell
$subjects = @{
  "gh-main"         = "repo:${REPO}:ref:refs/heads/main"          # plan job on push to main
  "gh-pull-request" = "repo:${REPO}:pull_request"                 # plan on PRs
  "gh-env-prod"     = "repo:${REPO}:environment:production"       # apply + destroy jobs
}
foreach ($name in $subjects.Keys) {
  $json = @{
    name      = $name
    issuer    = "https://token.actions.githubusercontent.com"
    subject   = $subjects[$name]
    audiences = @("api://AzureADTokenExchange")
  } | ConvertTo-Json
  $file = "$env:TEMP\$name.json"
  $json | Set-Content -Path $file -Encoding utf8
  az ad app federated-credential create --id $APP_ID --parameters "@$file"
}
az ad app federated-credential list --id $APP_ID --query "[].{name:name, subject:subject}" -o table
```

### Assign Azure roles to the identity

```powershell
# Create/modify resources
az role assignment create --assignee-object-id $SP_OBJECT_ID --assignee-principal-type ServicePrincipal `
  --role "Contributor" --scope "/subscriptions/$SUB"

# Needed because Terraform creates role assignments (VM managed identity -> storage / Key Vault).
# Least-privilege alternative: "Role Based Access Control Administrator" with a condition limiting assignable roles.
az role assignment create --assignee-object-id $SP_OBJECT_ID --assignee-principal-type ServicePrincipal `
  --role "User Access Administrator" --scope "/subscriptions/$SUB"
```

The state-storage data role (Storage Blob Data Contributor) gets assigned by `bootstrap/` in step 7.

### Identity module permissions (Conditional Access / PIM / Entra logs)

Terraform manages Entra ID objects too, so the CI identity needs directory permissions. Choose one option and **use the same `enable_*` values locally and in CI**. If the values differ, Terraform will create resources in one place and delete them in the other.

**Option A — everything through CI (recommended once the P2 trial is active)**
1. Portal → **Entra ID → App registrations → gh-azure-secure-landing-zone → API permissions → Add a permission → Microsoft Graph → Application permissions**, then add:
   - `Policy.ReadWrite.ConditionalAccess`, `Policy.Read.All` (CA policies + named locations)
   - `Group.ReadWrite.All` (CA pilot group)
   - `RoleManagement.ReadWrite.Directory` (PIM eligibility request)
2. Click **Grant admin consent for <tenant>**.
3. For the Entra diagnostic setting (sign-in/audit logs → Log Analytics), assign the service principal the **Security Administrator** directory role. This is a powerful role, so remove it after the lab.
4. In tfvars, set `enable_identity_module = true`, `enable_entra_diagnostics = true`.

**Option B — keep CI out of Entra ID**
Set `enable_identity_module = false` and `enable_entra_diagnostics = false` everywhere. Then configure CA, PIM and the Entra diagnostic setting in the portal using [IDENTITY_MANUAL_STEPS.md](IDENTITY_MANUAL_STEPS.md). Say so honestly in the README.

---

## 6. Configure GitHub (repo → Settings)

### Secrets — *Settings → Secrets and variables → Actions → Secrets*

| Name | Value |
|---|---|
| `AZURE_CLIENT_ID` | `$APP_ID` from step 5 |
| `AZURE_TENANT_ID` | `<TENANT_ID>` |
| `AZURE_SUBSCRIPTION_ID` | `<SUBSCRIPTION_ID>` |
| `TFVARS` | The **full contents** of your local `terraform.tfvars` (copied from `terraform.tfvars.example` and filled in). This keeps CI and local runs identical. |

These are IDs, not passwords. With OIDC there is **no client secret** anywhere.

### Variables — *Settings → Secrets and variables → Actions → Variables*

| Name | Value |
|---|---|
| `TF_STATE_RESOURCE_GROUP` | `rg-slz-tfstate` (bootstrap output) |
| `TF_STATE_STORAGE_ACCOUNT` | `sttfstate<random>` (bootstrap output) |

### Environment = manual approval gate — *Settings → Environments → New environment*
- Name: `production`
- **Required reviewers**: add yourself (`christiangallon`)
- **Deployment branches and tags**: *Selected branches* → `main`

### Branch protection — *Settings → Branches → Add branch ruleset* (or classic rule) for `main`
- Require a pull request before merging (approvals: 0 if you're solo; the environment gate is your approval)
- Require status checks to pass: `fmt / validate / tflint / checkov` and `terraform plan` *(these only show up in the picker after they've run once, so finish step 8 and then come back)*
- Block force pushes, and restrict deletions

With the GitHub CLI you can set secrets from PowerShell instead:

```powershell
gh auth login
gh secret set AZURE_CLIENT_ID --body $APP_ID
gh secret set AZURE_TENANT_ID --body $TENANT
gh secret set AZURE_SUBSCRIPTION_ID --body $SUB
Get-Content terraform.tfvars -Raw | gh secret set TFVARS
gh variable set TF_STATE_RESOURCE_GROUP --body "rg-slz-tfstate"
gh variable set TF_STATE_STORAGE_ACCOUNT --body "<STATE_STORAGE_ACCOUNT_NAME>"
```

---

## 7. Bootstrap remote state (once, locally)

```powershell
cd bootstrap
terraform init
terraform apply -var="subscription_id=<SUBSCRIPTION_ID>" -var="github_principal_object_id=<SP_OBJECT_ID>"
terraform output -raw backend_hcl
```

Copy that output into `..\backend.hcl` (git-ignored). Put the storage account name into the GitHub variable `TF_STATE_STORAGE_ACCOUNT`.

`bootstrap/terraform.tfstate` stays local and git-ignored. Keep it safe, and **never destroy bootstrap between sessions**. The state account has a delete lock and `prevent_destroy`.

## 8. First local plan, then the first PR

```powershell
cd ..
Copy-Item terraform.tfvars.example terraform.tfvars   # fill in placeholders
terraform init -backend-config=backend.hcl
terraform plan
```

Then trigger the pipeline:

```powershell
git checkout -b feature/first-plan
# make a small change, e.g. edit README status line
git add -A
git commit -m "chore: trigger first plan"
git push -u origin feature/first-plan
```

On GitHub, open a pull request into `main`. Check that the plan comment shows up. Merging makes the apply workflow pause for your approval on the `production` environment.

## 9. Tear down at the end of every session

```powershell
terraform destroy
```

Or: **Actions → terraform-destroy → Run workflow** → type `DESTROY` → approve.

---

### Troubleshooting

| Symptom | Fix |
|---|---|
| `AADSTS70021: No matching federated identity record` | The subject doesn't match. Check repo name/case, branch `main`, environment `production`. |
| `AuthorizationFailed` on role assignment | The SP is missing `User Access Administrator` (or RBAC Administrator). |
| `403` on state blob | The SP is missing `Storage Blob Data Contributor` on the state account. Re-run bootstrap with `github_principal_object_id`. |
| CA / group errors `Authorization_RequestDenied` | Graph permissions are missing, or admin consent wasn't granted (step 5, Option A). |
| Entra diagnostic setting `403` | The SP needs the Security Administrator directory role, or set `enable_entra_diagnostics = false`. |
| Key Vault name conflict after destroy | A soft-deleted vault still exists. `az keyvault purge --name <kv-name>` (or wait 7 days). |
