# tf-access-package

Terraform for adding an application's app role to a Microsoft Entra ID
**access package** as a resource role scope, using the
[`Microsoft/msgraph`](https://registry.terraform.io/providers/microsoft/msgraph/latest/docs)
provider.

The root module posts a single `resourceRoleScope` to an existing access
package, binding a `Doctor` app role at the application's root scope. The
`bootstrap/` module creates the prerequisite objects so the root module can be
tested end to end against a real tenant.

## Layout

| Path | Purpose |
| --- | --- |
| `template.tf` | The resource under test: adds the role scope to an access package. |
| `variables.tf` | The six directory IDs the template needs, plus `tenant_id`. |
| `provider.tf` | `msgraph` provider, pinned to a tenant. |
| `bootstrap/main.tf` | Creates app registration, `Doctor` app role, service principal, catalog, access package, and onboards the app as a catalog resource. Outputs every ID the root module needs. |
| `terraform.tfvars.example` | Placeholder values; copy to `terraform.tfvars`. |

## Authentication


Use a service principal with these Graph **application** permissions, admin
consented:

- `EntitlementManagement.ReadWrite.All`
- `Application.ReadWrite.All` — required by Graph to onboard a service principal
  as a catalog resource

```powershell
$env:ARM_CLIENT_ID     = '<app id>'
$env:ARM_CLIENT_SECRET = '<secret>'
$env:ARM_TENANT_ID     = '<tenant id>'
$env:ARM_USE_CLI       = 'false'
```

The tenant also needs an active Entra ID P2 / Governance licence
(`AAD_PREMIUM_P2` provisioned). A lapsed subscription reports
`capabilityStatus: LockedOut` and the service plans as `Disabled`.

## Usage

```powershell
cd bootstrap
terraform init
terraform apply -var "tenant_id=<tenant id>"
```

Copy the outputs into `terraform.tfvars`, then:

```powershell
cd ..
terraform init
terraform apply
```

## Notes

**The role scope uses `msgraph_resource_action`, not `msgraph_resource`.**
Graph exposes `accessPackages/{id}/resourceRoleScopes` as POST and list only —
`GET .../resourceRoleScopes/{id}` returns `404` on both `v1.0` and `beta`.
Because `msgraph_resource` polls that read-back to confirm creation, it hangs
until the create timeout expires and fails, even though the POST succeeded on
the first attempt. Worse, the failed create records nothing in state while the
role scope exists in the tenant, so a re-run silently creates duplicates.

**`catalog_role_id` is expected to be all zeros.** Graph returns
`00000000-0000-0000-0000-000000000000` for a catalog resource role until it is
bound to an access package, at which point a real ID is assigned. The role is
matched by `originId` (the appRole GUID), not by `id` or `displayName`.

**Destroy does not remove the role scope.** `msgraph_resource_action` performs a
one-shot call and manages no lifecycle, so `terraform destroy` drops it from
state without deleting it. Remove it with
`DELETE /beta/identityGovernance/entitlementManagement/accessPackages/{id}/accessPackageResourceRoleScopes/{roleId}_{scopeId}`.

**Adding a resource to a catalog is asynchronous.** `bootstrap/main.tf` waits 90
seconds after the `adminAdd` resource request before reading back the catalog
resource, its root scope, and its roles.
