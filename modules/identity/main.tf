# ---------------------------------------------------------------------------
# Entra ID controls: trusted named location, Conditional Access, PIM.
# Conditional Access requires Entra ID P1; PIM requires Entra ID P2.
# ---------------------------------------------------------------------------
locals {
  ca_state = var.ca_enforce ? "enabled" : "enabledForReportingButNotEnforced"
}

# Pilot group - CA policies target this group (not "All users") so a
# mistake cannot lock the whole tenant out. Add test users to it.
resource "azuread_group" "ca_pilot" {
  display_name     = "grp-${var.name_base}-ca-pilot"
  description      = "Users in scope of the landing-zone Conditional Access policies."
  security_enabled = true
}

resource "azuread_named_location" "trusted" {
  count = length(var.trusted_ip_ranges) > 0 ? 1 : 0

  display_name = "nl-${var.name_base}-trusted"

  ip {
    ip_ranges = var.trusted_ip_ranges
    trusted   = true
  }
}

# Policy 1: require MFA everywhere except the trusted named location.
resource "azuread_conditional_access_policy" "mfa_outside_trusted" {
  display_name = "CA01-${var.name_base}-require-mfa-outside-trusted-location"
  state        = local.ca_state

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_groups = [azuread_group.ca_pilot.object_id]
      excluded_users  = var.break_glass_object_ids
    }

    locations {
      included_locations = ["All"]
      excluded_locations = length(var.trusted_ip_ranges) > 0 ? [azuread_named_location.trusted[0].id] : []
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

# Policy 2: block legacy authentication (cannot do MFA).
resource "azuread_conditional_access_policy" "block_legacy_auth" {
  display_name = "CA02-${var.name_base}-block-legacy-authentication"
  state        = local.ca_state

  conditions {
    client_app_types = ["exchangeActiveSync", "other"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_groups = [azuread_group.ca_pilot.object_id]
      excluded_users  = var.break_glass_object_ids
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}

# ---------------------------------------------------------------------------
# PIM: eligible (not permanent) assignment of an admin role.
# Supported by the provider: the eligibility request itself.
# NOT supported by the azuread provider: role settings (max activation
# duration, require MFA/justification/approval on activation, eligibility
# expiry). Configure those in the portal - see docs/IDENTITY_MANUAL_STEPS.md.
# ---------------------------------------------------------------------------
resource "azuread_directory_role" "pim" {
  count = var.enable_pim ? 1 : 0

  display_name = var.pim_role_name
}

resource "azuread_directory_role_eligibility_schedule_request" "admin" {
  count = var.enable_pim ? 1 : 0

  role_definition_id = azuread_directory_role.pim[0].template_id
  principal_id       = var.pim_principal_object_id
  directory_scope_id = "/"
  justification      = "Just-in-time admin access for ${var.name_base} (managed by Terraform)"
}
