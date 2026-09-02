terraform {
  required_providers {
    msgraph = {
      source  = "Microsoft/msgraph"
      version = "~> 0.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "msgraph" {
  tenant_id = var.tenant_id
}

variable "tenant_id" {
  type        = string
  description = "Entra ID tenant to test against."
}

variable "prefix" {
  type        = string
  description = "Name prefix for the throwaway test objects."
  default     = "tf-access-package-test"
}

resource "random_uuid" "doctor_app_role" {}

resource "msgraph_resource" "application" {
  url = "applications"

  body = {
    displayName    = "${var.prefix}-app"
    signInAudience = "AzureADMyOrg"

    appRoles = [
      {
        id                 = random_uuid.doctor_app_role.result
        allowedMemberTypes = ["User"]
        displayName        = "Doctor"
        description        = "Doctor role used to test access package resource role scopes."
        value              = "Doctor"
        isEnabled          = true
      }
    ]
  }

  response_export_values = {
    app_id    = "appId"
    object_id = "id"
  }
}

resource "msgraph_resource" "service_principal" {
  url = "servicePrincipals"

  body = {
    appId = msgraph_resource.application.output.app_id
  }

  response_export_values = {
    object_id = "id"
  }

  # The application takes a moment to replicate before a service principal can reference it.
  retry = {
    error_message_regex = [
      ".*does not exist or one of its queried reference-property objects are not present.*",
      ".*Request_ResourceNotFound.*",
    ]
  }

  timeouts {
    create = "10m"
  }
}

resource "msgraph_resource" "catalog" {
  url = "identityGovernance/entitlementManagement/catalogs"

  body = {
    displayName         = "${var.prefix}-catalog"
    description         = "Throwaway catalog for testing template.tf"
    state               = "published"
    isExternallyVisible = false
  }

  response_export_values = {
    catalog_id = "id"
  }
}

resource "msgraph_resource" "access_package" {
  url = "identityGovernance/entitlementManagement/accessPackages"

  body = {
    displayName = "${var.prefix}-package"
    description = "Throwaway access package for testing template.tf"
    isHidden    = false
    catalog = {
      id = msgraph_resource.catalog.output.catalog_id
    }
  }

  response_export_values = {
    access_package_id = "id"
  }
}

resource "msgraph_resource_action" "add_app_to_catalog" {
  resource_url = "identityGovernance/entitlementManagement"
  action       = "resourceRequests"
  method       = "POST"

  body = {
    requestType = "adminAdd"
    catalog = {
      id = msgraph_resource.catalog.output.catalog_id
    }
    resource = {
      originId     = msgraph_resource.service_principal.output.object_id
      originSystem = "AadApplication"
    }
  }

  response_export_values = {
    state = "state"
  }

  retry = {
    error_message_regex = [
      ".*does not exist or one of its queried reference-property objects are not present.*",
      ".*Request_ResourceNotFound.*",
      ".*ResourceNotFound.*",
    ]
  }

  timeouts {
    create = "10m"
  }
}

# The resource request is processed asynchronously; roles and scopes appear shortly after.
resource "time_sleep" "wait_for_catalog_resource" {
  depends_on      = [msgraph_resource_action.add_app_to_catalog]
  create_duration = "90s"
}

data "msgraph_resource" "catalog_resources" {
  url = "identityGovernance/entitlementManagement/catalogs/${msgraph_resource.catalog.output.catalog_id}/resources"

  query_parameters = {
    "$expand" = ["scopes"]
  }

  response_export_values = {
    resource_id = "value[?originId=='${msgraph_resource.service_principal.output.object_id}'] | [0].id"
    scope_id    = "value[?originId=='${msgraph_resource.service_principal.output.object_id}'] | [0].scopes[0].id"
  }

  depends_on = [time_sleep.wait_for_catalog_resource]
}

data "msgraph_resource" "catalog_resource_roles" {
  url = "identityGovernance/entitlementManagement/catalogs/${msgraph_resource.catalog.output.catalog_id}/resourceRoles"

  query_parameters = {
    "$filter" = ["(originSystem eq 'AadApplication' and resource/id eq '${data.msgraph_resource.catalog_resources.output.resource_id}')"]
  }

  response_export_values = {
    role_id = "value[?displayName=='Doctor'] | [0].id"
  }
}

output "tenant_id" {
  value = var.tenant_id
}

output "access_package_id" {
  value = msgraph_resource.access_package.output.access_package_id
}

output "service_principal_object_id" {
  value = msgraph_resource.service_principal.output.object_id
}

output "app_role_id" {
  value = random_uuid.doctor_app_role.result
}

output "catalog_id" {
  value = msgraph_resource.catalog.output.catalog_id
}

output "catalog_resource_id" {
  value = data.msgraph_resource.catalog_resources.output.resource_id
}

output "catalog_scope_id" {
  value = data.msgraph_resource.catalog_resources.output.scope_id
}

output "catalog_role_id" {
  value = data.msgraph_resource.catalog_resource_roles.output.role_id
}
