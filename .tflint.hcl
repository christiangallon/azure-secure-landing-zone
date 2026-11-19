# TFLint configuration - run with: tflint --init && tflint --recursive
config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.33.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# The lab is destroyed after every session by design (cost), so
# prevent_destroy is intentionally not used on workload resources.
# The remote-state account in bootstrap/ IS protected (lifecycle + lock).
rule "azurerm_resources_missing_prevent_destroy" {
  enabled = false
}
