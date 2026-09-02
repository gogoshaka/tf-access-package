


terraform {
  required_providers {
    msgraph = {
      source  = "Microsoft/msgraph"
      version = "~> 0.5"
    }
  }
}

# Graph exposes resourceRoleScopes as POST/list only, with no GET by ID, so
# msgraph_resource would block forever waiting on a read-back that never succeeds.
resource "msgraph_resource_action" "package_app_role" {
  resource_url = "identityGovernance/entitlementManagement/accessPackages/${var.access_package_id}"
  action       = "resourceRoleScopes"
  method       = "POST"

  body = {
    role = {
      id           = var.catalog_role_id
      displayName  = "Doctor"
      originSystem = "AadApplication"
      originId     = var.app_role_id

      resource = {
        id           = var.catalog_resource_id
        originId     = var.service_principal_object_id
        originSystem = "AadApplication"
      }
    }

    scope = {
      id           = var.catalog_scope_id
      originId     = var.service_principal_object_id
      originSystem = "AadApplication"
      isRootScope  = true
    }
  }

  response_export_values = {
    id = "id"
  }
}