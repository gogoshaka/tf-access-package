variable "tenant_id" {
  type        = string
  description = "Entra ID tenant to deploy against."
}

variable "access_package_id" {
  type        = string
  description = "ID of the access package that the resource role scope is added to."
}

variable "catalog_resource_id" {
  type        = string
  description = "ID of the accessPackageResource inside the catalog (the onboarded application)."
}

variable "catalog_role_id" {
  type        = string
  description = "ID of the accessPackageResourceRole in the catalog that maps to the Doctor app role."
}

variable "catalog_scope_id" {
  type        = string
  description = "ID of the accessPackageResourceScope in the catalog (root scope of the application)."
}

variable "app_role_id" {
  type        = string
  description = "GUID of the Doctor appRole defined on the application registration."
}

variable "service_principal_object_id" {
  type        = string
  description = "Object ID of the service principal backing the application."
}
