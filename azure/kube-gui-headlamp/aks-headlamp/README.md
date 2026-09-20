# Example: Headlamp on an existing AKS cluster

A complete, runnable configuration that calls the `headlamp` module. It contains
no module implementation of its own: everything under `modules/headlamp` is
referenced, never copied.

## What this example demonstrates

- Headlamp deployed from the Helm chart vendored inside the module at
  `modules/headlamp/charts`, so no chart download happens at apply time. The
  declared version is checked against the vendored chart before install.
- Microsoft Entra ID sign-in over OIDC, with the App Registration owned outside
  Terraform.
- Six Entra groups with three different access levels, across both cluster and
  namespace scope.
- A custom role defined alongside the built-in read, write and admin sets.
- Ingress with TLS, with no assumption about which controller is installed.

## Access matrix

This is one plausible arrangement, not a recommendation. What belongs in each
tier depends on your organisation.

| Entra group | Module role | Scope | Namespaces | Binding created |
| --- | --- | --- | --- | --- |
| `adgroup-aks-admin` | `admin` | cluster | all | `headlamp-crb-aks-admin` |
| `adgroup-aks-read` | `read` | cluster | all | `headlamp-crb-aks-read` |
| `adgroup-aks-write` | `write` | namespace | `team-a`, `team-b` | `headlamp-rb-team-a-aks-write`, `headlamp-rb-team-b-aks-write` |
| `adgroup-app-a-read` | `read` | namespace | `application-a` | `headlamp-rb-application-a-app-a-read` |
| `adgroup-app-a-write` | `write` | namespace | `application-a` | `headlamp-rb-application-a-app-a-write` |
| `adgroup-app-a-operator` | `application-operator` | namespace | `application-a` | `headlamp-rb-application-a-app-a-operator` |

Note what is absent: `adgroup-aks-write` has no access to `team-c` or to any
namespace created later. That is the point of using RoleBindings instead of a
ClusterRoleBinding for namespace-scoped groups.

## Before you run

1. **The App Registration must already exist.** Nothing here creates it. Follow
   section 5 of the [module README](../modules/headlamp/README.md), which
   lists the redirect URI, API permissions and admin consent required.
2. **The Entra groups must already exist**, and you need their object IDs:

   ```bash
   az ad group show --group adgroup-aks-admin --query id -o tsv
   ```

3. **The application namespaces must exist** (`team-a`, `team-b`,
   `application-a`). The module binds permissions into them but does not create
   them.
4. **A kubeconfig pointing at the cluster:**

   ```bash
   az aks get-credentials --resource-group <rg> --name <cluster>
   kubelogin convert-kubeconfig -l azurecli
   ```

   The second command matters on an Entra-integrated cluster. It rewrites the
   kubeconfig to obtain tokens through the Azure CLI rather than the removed
   in-tree provider.

5. **A TLS certificate** in a Kubernetes Secret named by
   `ingress_tls_secret_name`, and a DNS record for `headlamp_hostname`.

## Run it

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars

terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
terraform apply
```

If you are letting Terraform create the OIDC Secret rather than referencing an
existing one, pass the client secret through the environment and never through a
file:

```bash
export TF_VAR_oidc_client_secret='...'
```

## After apply

Check that the callback URL Terraform derived matches what is registered on the
App Registration. A mismatch is the single most common cause of a failed
sign-in:

```bash
terraform output oidc_redirect_url
```

Review who ended up with what:

```bash
terraform output access_matrix
```

Confirm the Headlamp pod itself holds no cluster permissions. This should print
`false`:

```bash
terraform output headlamp_service_account_has_cluster_role_binding
```

## Verify access

```bash
# The write group can deploy into a granted namespace
kubectl auth can-i create deployments -n team-a \
  --as-group="$(terraform output -raw -json access_matrix | jq -r '."aks-write".object_id')" \
  --as="verify@example.com"

# The same group must be refused in a namespace it was never granted
kubectl auth can-i create deployments -n team-c \
  --as-group="<WRITE_GROUP_OBJECT_ID>" --as="verify@example.com"

# The read group must not be able to read secrets
kubectl auth can-i get secrets \
  --as-group="<READ_GROUP_OBJECT_ID>" --as="verify@example.com"
```

Then sign in through the browser as a member of each group and confirm the
visible namespaces match the table above. The `can-i` checks prove the RBAC
objects are right; only a real sign-in also proves the token audience and groups
claim are right.

## Tear down

```bash
terraform plan -destroy
terraform destroy
```

This removes Headlamp and the RBAC bindings. It does not touch the App
Registration, the Entra groups, the AKS cluster or the application namespaces,
because none of them were managed here.
