# Terraform module: Headlamp on AKS

Deploys [Headlamp](https://headlamp.dev/) into an existing Azure Kubernetes
Service cluster, wires it to Microsoft Entra ID for sign-in, and maps Entra
groups to Kubernetes RBAC.

Headlamp is only the user interface. Every authorisation decision is made by the
Kubernetes API server against the RBAC objects this module creates.

---

## 1. Architecture

```text
User (browser)
  |
  | 1. redirected to Entra ID, signs in
  v
Microsoft Entra ID  ----------------------------------------+
  |                                                         |
  | 2. authorization code -> /oidc-callback                  | groups claim
  |    access token, audience = AKS AAD Server app           | (group object IDs)
  v                                                         |
Headlamp (pod in the headlamp namespace)                     |
  |                                                         |
  | 3. forwards the user's token on every API call           |
  v                                                         |
AKS Kubernetes API server                                    |
  |                                                         |
  | 4. validates the token with Entra, reads the groups -----+
  v
Kubernetes RBAC
  |
  +-- ClusterRoleBinding  -> cluster-wide groups
  |
  +-- RoleBinding         -> namespace-scoped groups
  |
  +-- subjects: kind = Group, name = Entra group object ID
```

The critical property is step 3. Headlamp does not call the API with its own
identity; it passes the signed-in user's token through. Two consequences follow,
and they drive most of the module's defaults:

- The Headlamp pod needs no cluster permissions of its own.
- Everything a user can see or do is decided by the RBAC bindings below, so the
  bindings are the real security surface, not the GUI.

### Files

| File | Contents |
| --- | --- |
| `main.tf` | Namespace, OIDC Secret, Helm release |
| `rbac.tf` | ClusterRoles, Roles and the bindings to Entra groups |
| `locals.tf` | Chart source, label sets, OIDC wiring, Helm values, RBAC flattening |
| `variables.tf` | All inputs |
| `outputs.tf` | All outputs |
| `versions.tf` | Terraform and provider constraints |
| `charts/` | The Headlamp chart itself, vendored and installed from here |

`rbac.tf` is a deliberate addition to the minimum file set. Authorisation is a
different concern with a different review audience from the deployment, and
keeping the two apart means a change to who can delete pods never appears in the
same diff as a change to the chart version.

---

## 2. Prerequisites

| Requirement | Why |
| --- | --- |
| Terraform >= 1.9.0 | Input validation rules reference other variables |
| `hashicorp/helm` >= 3.0 | Provider is configured by the caller, not the module |
| `hashicorp/kubernetes` >= 2.30 | Uses the `_v1` resource names |
| An existing AKS cluster | The module never creates or modifies the cluster |
| Permission to create namespaces, Secrets and cluster-scoped RBAC | Creating ClusterRoles requires a caller who already holds those permissions |
| An Entra App Registration | Created outside Terraform, see section 5 |

The caller configures both providers. The module contains no credentials, no
kubeconfig, no subscription ID and no tenant ID.

---

## 3. AKS requirements

- **Kubernetes RBAC enabled.** A cluster using Azure RBAC for Kubernetes
  authorization instead makes its authorisation decisions in Azure, and the
  Roles and bindings created here are then ignored. Check with:
  `az aks show -g <rg> -n <cluster> --query aadProfile`.
- **Microsoft Entra integration enabled** (`aadProfile.managed` is `true`). This
  is what makes the API server accept Entra tokens and read the groups claim.
- **Network reachability** from wherever Terraform runs to the API server. On a
  private cluster that means a self-hosted runner, a jump host or a VPN.
- The namespaces referenced in `rbac_groups` must exist, or the RoleBindings
  will be created but grant nothing until they do. The module does not create
  application namespaces; that belongs to whatever owns those workloads.

---

## 4. Microsoft Entra requirements

- Entra groups exist for each access level, and users are members.
- You know each group's **object ID**. Display names are not accepted:

  ```bash
  az ad group show --group adgroup-aks-read --query id -o tsv
  ```

- Admin consent has been granted on the App Registration (section 5), because
  the AKS scope is an admin-consentable delegated permission in most tenants.

### Group claim limits

Entra does not put an unlimited number of groups into a token. Past the limit it
omits the `groups` claim and sets a `_claim_names` / `_claim_sources` pair
pointing at the Graph API instead, which is known as group overage. When that
happens the API server sees no groups and the user loses all access, usually
presenting as an empty Headlamp with permission errors everywhere.

Mitigations, none of which this module can apply for you:

- Use the **Groups assigned to the application** option on the App Registration
  so only the groups relevant to AKS are emitted.
- Keep users in fewer directly assigned groups.

This module does not attempt to resolve group overage automatically. Doing so
would require Headlamp to call Microsoft Graph on the user's behalf, which is
outside what the OIDC flow described here does.

---

## 5. External App Registration boundary

> **This Terraform module does not create or manage the Microsoft Entra App
> Registration / Enterprise Application. The application must be created and
> configured separately.**

The module creates no App Registration, no Enterprise Application, no client
secret, no Graph or API permission, no admin consent, no Entra group and no
Entra user. It accepts the resulting values as inputs.

This is deliberate. Application registrations are directory objects with a
different owner, a different approval path and a different lifecycle from a
Kubernetes workload. Creating them from the same state file that deploys a GUI
means a `terraform destroy` on the GUI can delete the identity that other
systems depend on.

### What must be created externally

| Step | Value |
| --- | --- |
| 1 | App Registration, single tenant, for example named `headlamp-oidc` |
| 2 | Platform **Web**, redirect URI `https://<HEADLAMP_HOST>/oidc-callback` |
| 3 | API permission: **Azure Kubernetes Service AAD Server** (`6dae42f8-4368-4678-94ff-3960e28e3630`), delegated `user.read` |
| 4 | API permission: **Microsoft Graph** delegated `openid`, `email`, `profile` |
| 5 | Grant admin consent for the tenant |
| 6 | Certificates & secrets: create a client secret, record the value |
| 7 | Record the Application (client) ID and the Directory (tenant) ID |

Record the client secret expiry. Nothing in this module renews it, and sign-in
breaks the day it lapses.

---

## 6. Required OIDC values

| Module input | Value for AKS |
| --- | --- |
| `oidc_client_id` | Application (client) ID from step 7 |
| `oidc_client_secret` | Client secret from step 6, or supplied through `oidc_existing_secret_name` |
| `oidc_issuer_url` | `https://login.microsoftonline.com/<TENANT_ID>/v2.0` |
| `oidc_scopes` | `6dae42f8-4368-4678-94ff-3960e28e3630/user.read`, `openid`, `email`, `profile` |
| `oidc_use_access_token` | `true` |
| `oidc_validator_client_id` | `6dae42f8-4368-4678-94ff-3960e28e3630` |
| `oidc_validator_issuer_url` | `https://sts.windows.net/<TENANT_ID>/` |
| `oidc_redirect_url` | `https://<HEADLAMP_HOST>/oidc-callback`, derived from the ingress host when left null |

### Why the token audience is the fiddly part

An ID token issued to the Headlamp App Registration has that application as its
audience. The AKS API server does not accept it, and sign-in appears to succeed
while every API call returns 401.

The fix is the combination of three settings above. Requesting the AKS AAD
Server scope yields an **access token** whose audience is the application the API
server does accept, and `oidc_use_access_token` tells Headlamp to send that
token instead of the ID token. Because Entra issues that access token from its
v1 endpoint, validation uses `https://sts.windows.net/<TENANT_ID>/` even though
sign-in used the v2.0 issuer. The two issuer values differing is expected, not a
mistake.

The module defaults already encode all of this.

---

## 7. Usage

```hcl
module "headlamp" {
  source = "../modules/headlamp"

  headlamp_namespace     = "headlamp"
  headlamp_chart_version = "0.45.0"

  oidc_client_id            = var.oidc_client_id
  oidc_issuer_url           = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
  oidc_validator_issuer_url = "https://sts.windows.net/${var.tenant_id}/"
  oidc_existing_secret_name = "headlamp-oidc"

  ingress_enabled         = true
  ingress_class_name      = "nginx"
  ingress_host            = "headlamp.example.com"
  ingress_tls_secret_name = "headlamp-tls"

  rbac_groups = {
    aks-admin = {
      object_id = "00000000-0000-0000-0000-000000000000"
      scope     = "cluster"
      role      = "admin"
    }
    aks-write = {
      object_id  = "11111111-1111-1111-1111-111111111111"
      scope      = "namespace"
      role       = "write"
      namespaces = ["team-a", "team-b"]
    }
  }
}
```

A complete configuration is in `aks-headlamp/`.

### Chart source

The chart is vendored at `charts/` inside this module and is installed from
there by default. The path is resolved from `path.module`, so it works no matter
which directory Terraform runs from.

```hcl
headlamp_use_local_chart = true    # default
headlamp_chart_version   = "0.45.0"
```

Two properties follow from this:

- **No egress needed for the chart.** `terraform plan` and `apply` do not reach
  out to the chart repository. The machine running Terraform still needs access
  to the Kubernetes API, and to the Terraform provider registry at `init` time.
- **What you reviewed is what you install.** A vendored chart cannot change
  between review and apply, which a remote reference can if the repository
  republishes a version.

The usual objection to vendoring is that the version pin disappears from the
code, so a swapped chart produces no diff. That is handled: the module reads
`charts/Chart.yaml` and fails the plan if its version does not match
`headlamp_chart_version`.

```text
Error: Resource precondition failed

The vendored chart's version does not match headlamp_chart_version.
```

To track upstream releases from the repository instead:

```hcl
headlamp_use_local_chart  = false
headlamp_chart_repository = "https://kubernetes-sigs.github.io/headlamp/"
headlamp_chart_version    = "0.45.0"
```

`headlamp_chart_repository` also accepts an internal mirror or an OCI registry,
for example `oci://myacr.azurecr.io/helm`. OCI registries need credentials in
the `helm` provider's `registries` block in the root module.

#### Upgrading the vendored chart

```bash
curl -sSL -o /tmp/headlamp-<NEW>.tgz \
  https://github.com/kubernetes-sigs/headlamp/releases/download/headlamp-helm-<NEW>/headlamp-<NEW>.tgz

# Verify against the digest the repository declares, not against the file itself
curl -sS https://kubernetes-sigs.github.io/headlamp/index.yaml \
  | grep -B5 'headlamp-<NEW>.tgz' | grep digest
sha256sum /tmp/headlamp-<NEW>.tgz

rm -rf modules/headlamp/charts
mkdir -p modules/headlamp/charts
tar -xzf /tmp/headlamp-<NEW>.tgz --strip-components=1 -C modules/headlamp/charts
```

Then set `headlamp_chart_version` to the new version, read the chart's release
notes for renamed values, and run a plan. The version precondition is what tells
you if you forgot one of the two halves.

> Verifying an unpacked chart directory against the published digest is not
> possible, because the digest covers the archive. Do the checksum check at
> download time, as above, before unpacking. If you need the check to be
> repeatable in CI, keep the `.tgz` alongside the unpacked directory and verify
> that instead.

#### Disconnected clusters

Vendoring the chart solves the build agent's network access. It does not solve
the cluster's. Nodes still pull `ghcr.io/headlamp-k8s/headlamp:v0.45.0`
themselves. Mirror that image and override the registry:

```hcl
headlamp_extra_values = [yamlencode({
  image = {
    registry   = "myacr.azurecr.io"
    repository = "mirror/headlamp"
  }
  imagePullSecrets = [{ name = "acr-pull" }]
})]
```

The chart builds the tag as `v<appVersion>`, so the mirrored tag must carry the
leading `v`.

---

## 8. RBAC configuration

Each entry in `rbac_groups` describes one Entra group. Exactly one permission
source must be set:

| Field | Effect |
| --- | --- |
| `role` | A key in `rbac_role_definitions` or `custom_roles`. The module creates that ClusterRole and binds it. |
| `cluster_role_name` | Binds an existing ClusterRole such as `view` or `edit`. Nothing is created. |
| `namespace_role_name` | A key in `namespace_roles`. Binds a namespace-scoped Role. Namespace scope only. |

`scope` decides the binding kind: `cluster` produces a ClusterRoleBinding,
`namespace` produces one RoleBinding per namespace listed. Bindings are
generated with `for_each` over the map and over a flattened list of
`(group, namespace)` pairs, so any number of groups and namespaces is supported
and nothing is hard-coded.

Only role definitions that a group actually references are created, which keeps
unused ClusterRoles out of the cluster.

### Built-in role definitions

`read`, `write` and `admin` ship as defaults in `rbac_role_definitions` and are
written out as explicit resource and verb lists. None of them is `cluster-admin`.
Override any key to redefine what that word means in your organisation.

| Role | Verbs | Notable inclusions | Notable exclusions |
| --- | --- | --- | --- |
| `read` | get, list, watch | workloads, networking, metrics, plus cluster-scoped objects that only take effect via a ClusterRoleBinding | **no secrets**, no RBAC objects |
| `write` | read verbs plus create, update, patch, delete | workloads, services, configmaps, ingresses, HPAs, **secrets** | no `pods/exec`, no RBAC objects, no namespace creation |
| `admin` | full CRUD on the enumerated set | `pods/exec`, `pods/portforward`, namespaces, RBAC objects, storage classes, CRD read | not a wildcard: no `apiGroups: ["*"]` anywhere |

### Custom roles

```hcl
custom_roles = {
  application-operator = {
    rules = [
      {
        api_groups = ["apps"]
        resources  = ["deployments", "deployments/scale"]
        verbs      = ["get", "list", "watch", "update", "patch"]
      },
      {
        api_groups = [""]
        resources  = ["pods", "pods/log"]
        verbs      = ["get", "list", "watch"]
      },
    ]
  }
}
```

Rules are a list rather than one `api_groups`/`resources`/`verbs` triple, because
almost every real role needs more than one rule. Reading pods and reading pod
logs are two separate rules.

---

## 9. Namespace-scoped access

```hcl
rbac_groups = {
  app-a-write = {
    object_id  = "..."
    scope      = "namespace"
    role       = "write"
    namespaces = ["application-a"]
  }
}
```

This produces one RoleBinding named `headlamp-rb-application-a-app-a-write` in
namespace `application-a`, referencing the ClusterRole `headlamp-rbac-write`.

Referencing a ClusterRole from a RoleBinding is intentional. The permission set
is defined once and granted separately in each namespace, rather than copying an
identical Role into every namespace. Rules in that ClusterRole that name
cluster-scoped resources, such as `nodes`, simply have no effect through a
RoleBinding.

A ClusterRoleBinding is never generated for a namespace-scoped group. That would
grant the role in every namespace and destroy the isolation the scope is asking
for.

Use `namespace_roles` plus `namespace_role_name` when the permission set should
not exist as a cluster-wide object at all. A RoleBinding can only reference a
Role in its own namespace, and the module enforces that with a precondition.

---

## 10. Cluster-wide access

```hcl
rbac_groups = {
  aks-read = {
    object_id = "..."
    scope     = "cluster"
    role      = "read"
  }
}
```

This produces a single ClusterRoleBinding named `headlamp-crb-aks-read`. It
covers every namespace, including namespaces created later, which is usually the
point for a platform-wide read role.

Listing `namespaces` alongside `scope = "cluster"` is rejected by validation
rather than silently ignored.

---

## 11. Admin access

The `admin` role definition enumerates its permissions instead of reaching for
`cluster-admin`. It is broad, and you should read it before using it: it
includes `pods/exec`, write access to Secrets, and write access to RBAC objects.

Write access to RBAC objects is privilege escalation by definition. A user who
can create ClusterRoleBindings can grant themselves anything. That is a
reasonable definition of cluster administrator, but it should be a conscious
choice, so treat this group as equivalent to a cluster owner for access-review
purposes.

If you genuinely want the built-in `cluster-admin`, ask for it explicitly:

```hcl
aks-admin = {
  object_id         = "..."
  scope             = "cluster"
  cluster_role_name = "cluster-admin"
}
```

---

## 12. Secret management

Two modes, both of which route the credentials through the chart's
`externalSecret` path so that the client secret never appears in Helm values or
in the Helm release data stored in the cluster.

### Existing Secret (recommended)

```hcl
oidc_existing_secret_name = "headlamp-oidc"
```

Terraform creates nothing and references a Secret you manage elsewhere. The
Secret must live in the Headlamp namespace and contain exactly these keys, which
the chart consumes with `envFrom`:

```text
OIDC_CLIENT_ID
OIDC_CLIENT_SECRET
OIDC_ISSUER_URL
```

In practice this is populated by the Secrets Store CSI driver reading Azure Key
Vault, or by the External Secrets Operator. The client secret then never enters
Terraform state, and rotating it does not require a Terraform run.

### Terraform-created Secret

```hcl
oidc_client_id     = "..."
oidc_client_secret = var.oidc_client_secret  # from TF_VAR_oidc_client_secret
oidc_issuer_url    = "https://login.microsoftonline.com/<TENANT_ID>/v2.0"
```

> The client secret is stored **in Terraform state in plain text**. Use a remote
> backend with encryption at rest and tight access control, and treat the state
> file as a credential. The output `oidc_secret_managed_by_terraform` reports
> which mode is active.

Setting both inputs is rejected by a precondition. No output exposes secret
material; `oidc_secret_name` returns a name only.

Scopes, callback URL and the validator settings are passed as plain pod
environment variables rather than through the Secret. They are not credentials,
and keeping them out of the Secret means the Secret's contents are the same
three keys regardless of configuration.

---

## 13. Ingress

Ingress is optional and off by default, so nothing is published without an
explicit decision.

```hcl
ingress_enabled         = true
ingress_class_name      = "nginx"
ingress_host            = "headlamp.example.com"
ingress_tls_enabled     = true
ingress_tls_secret_name = "headlamp-tls"
ingress_annotations     = { "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true" }
```

No controller is assumed. The module sets `ingressClassName` from your input and
passes annotations straight through, so NGINX, Application Gateway for
Containers, the AKS web application routing add-on, Istio or anything else works
the same way. Controller-specific behaviour belongs in `ingress_annotations`.

The Service stays `ClusterIP` by default. Switch `service_type` to
`LoadBalancer` only deliberately, and prefer an internal load balancer
annotation if you do.

---

## 14. HTTPS

Serve Headlamp over TLS. The OIDC authorization code and the resulting tokens
travel through the browser, and a plain HTTP listener exposes them on the
network.

- Terminate TLS at the ingress controller with a real certificate.
- Redirect HTTP to HTTPS using your controller's annotation.
- Register an `https://` redirect URI on the App Registration. Entra rejects
  plain HTTP redirect URIs for anything but localhost.
- When `ingress_tls_enabled` is true the module derives the callback URL as
  `https://<host>/oidc-callback`. Setting it false derives an `http://` URL,
  which Entra will refuse, and that is intentional friction.

---

## 15. Verification

### Terraform

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform plan
```

`fmt`, `init` and `validate` pass on this module with Terraform 1.15.6,
`hashicorp/helm` 3.3.0 and `hashicorp/kubernetes` 3.2.1. `plan` needs a
reachable cluster and was not run during authoring.

### Kubernetes objects

```bash
kubectl get clusterrole      -l app.kubernetes.io/name=headlamp
kubectl get clusterrolebinding -l app.kubernetes.io/name=headlamp
kubectl get role        -A -l app.kubernetes.io/name=headlamp
kubectl get rolebinding -A -l app.kubernetes.io/name=headlamp
kubectl get all -n headlamp
```

### Effective permissions

`kubectl auth can-i` with `--as-group` asks the API server to evaluate the
request as a member of that group. It needs impersonation rights on the caller.

```bash
# Cluster-wide read group can list pods anywhere
kubectl auth can-i list pods \
  --as-group="<READ_GROUP_OBJECT_ID>" --as="verify@example.com"

# Read group must not be able to read secrets
kubectl auth can-i get secrets \
  --as-group="<READ_GROUP_OBJECT_ID>" --as="verify@example.com"

# Write group inside a granted namespace
kubectl auth can-i create deployments -n team-a \
  --as-group="<WRITE_GROUP_OBJECT_ID>" --as="verify@example.com"

kubectl auth can-i create deployments -n team-b \
  --as-group="<WRITE_GROUP_OBJECT_ID>" --as="verify@example.com"

# Negative test: a namespace that was never granted. Must print "no".
kubectl auth can-i create deployments -n team-c \
  --as-group="<WRITE_GROUP_OBJECT_ID>" --as="verify@example.com"

# Everything a group may do in one namespace
kubectl auth can-i --list -n team-a \
  --as-group="<WRITE_GROUP_OBJECT_ID>" --as="verify@example.com"
```

The negative test matters most. A configuration that passes every positive check
can still be wrong if a ClusterRoleBinding crept in where a RoleBinding was
intended.

> **ข้อมูลนี้ไม่สามารถยืนยันได้**: the exact `kubectl auth can-i` flag syntax was
> not verified against an installed kubectl, because no kubectl binary is present
> in the environment where this module was written. Confirm with
> `kubectl auth can-i --help` on your own version before relying on these
> commands in a pipeline. Note also that `--as-group` usually requires `--as` to
> be supplied as well, and that impersonation itself requires permission.

### End-to-end

Sign in as a member of each group and confirm the namespace list in Headlamp
matches the access matrix. RBAC checks confirm the API server's view; only a
real sign-in confirms the token audience and groups claim are also correct.

---

## 16. Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `AADSTS50011: redirect URI mismatch` | The `oidc_redirect_url` output does not match a redirect URI on the App Registration. Compare them character for character, including the scheme and any trailing path. |
| Sign-in succeeds, then every view is empty or 401 | Token audience. Confirm `oidc_use_access_token` is true and that the AKS AAD Server scope is in `oidc_scopes`. |
| Sign-in succeeds, user sees nothing, no error | The groups claim is missing or the object ID is wrong. Decode the token at jwt.ms and look for `groups`. If `_claim_names` is present instead, this is group overage; see section 4. |
| Pod stuck in `CreateContainerConfigError` | The OIDC Secret is missing or has the wrong keys. It must contain `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` and `OIDC_ISSUER_URL`. |
| `Error: unauthorized` from Terraform itself | The kubeconfig token expired. Re-run `az aks get-credentials` and `kubelogin convert-kubeconfig -l azurecli`. |
| Bindings exist but grant nothing | The cluster uses Azure RBAC for Kubernetes authorization, so Kubernetes RBAC objects are not consulted. Check `aadProfile` on the cluster. |
| Helm release times out waiting | Inspect the pod: `kubectl -n headlamp describe pod` and `kubectl -n headlamp logs deploy/headlamp`. `atomic` rolls the release back, so the failing pod may already be gone; set `helm_atomic = false` temporarily to keep it for inspection. |

Useful commands:

```bash
kubectl -n headlamp logs deploy/headlamp
kubectl -n headlamp get deploy headlamp -o jsonpath='{.spec.template.spec.containers[0].args}'
helm -n headlamp get values headlamp
```

The second command prints the resolved Headlamp command line, which is the
fastest way to confirm the OIDC flags actually reached the container.

---

## 17. Upgrade procedure

1. Change `headlamp_chart_version` to the new pinned version.
2. Read the chart's release notes for renamed or removed values.
3. `terraform plan` and inspect the diff.
4. `terraform apply`.

Helm performs a rolling upgrade. `atomic` and `cleanup_on_fail` are on by
default, so a failed upgrade rolls back to the previous revision rather than
leaving a half-applied release. `max_history` keeps the last 10 revisions for
`helm rollback`.

`force_update` and `recreate_pods` are deliberately not enabled. Both replace
running pods on every apply, which turns an unrelated values change into an
avoidable restart.

RBAC changes apply immediately on the next API request; no pod restart is
involved. Removing a group from `rbac_groups` deletes its bindings on the next
apply, and that user loses access at once.

---

## 18. Destroy procedure

```bash
terraform plan -destroy
terraform destroy
```

Order is handled by Terraform: the Helm release goes first, then the Secret, then
the namespace. The namespace is destroyed only if `create_namespace` was true.

What is **not** removed, because it was never managed here: the App
Registration, its client secret, the Entra groups, the AKS cluster, application
namespaces, and any Secret referenced through `oidc_existing_secret_name`.

Destroying the module removes the GUI and the RBAC grants that came with it.
Anyone whose only access was through a binding created here loses cluster access.

---

## 19. Security considerations

**The Headlamp service account.** The upstream chart defaults to creating a
ClusterRoleBinding that binds Headlamp's own ServiceAccount to `cluster-admin`.
This module sets `headlamp_cluster_role_binding_enabled = false`. Leaving the
chart default in place would give the pod standing cluster-admin, which turns any
path to the pod into a full cluster compromise and makes per-user RBAC
decorative. `headlamp_cluster_role_binding_role_name` additionally refuses the
value `cluster-admin`.

**Secret access is secret disclosure.** Anything that can `get` a Secret can read
its decoded contents. The default `write` role includes Secrets because managing
workloads usually requires it; the default `read` role deliberately does not. If
your write users should not see credentials, remove `secrets` from the `write`
definition and grant it through a separate role to a smaller group.

**RBAC write is privilege escalation.** The `admin` role can create
ClusterRoleBindings, and therefore can grant itself anything. Scope that group
accordingly.

**Least privilege by construction.** Roles are explicit resource and verb lists.
No definition uses `apiGroups: ["*"]` or `verbs: ["*"]`, and `cluster-admin` is
never used unless you name it yourself.

**Workload hardening.** The pod runs as non-root (UID 100), with a read-only root
filesystem, all capabilities dropped, no privilege escalation, and the
`RuntimeDefault` seccomp profile. Requests and limits are set, and liveness and
readiness probes are configured. Two replicas and a PodDisruptionBudget are the
default.

**Transport.** Use TLS. See section 14.

**Not exposed by default.** The Service is `ClusterIP` and ingress is off until
you enable it.

**NetworkPolicy.** The module does not create one, because a policy that assumes
the wrong CNI or the wrong ingress controller namespace silently breaks access.
Apply your own restricting ingress to the Headlamp pod to the ingress controller
namespace, and egress to the Kubernetes API and the Entra endpoints. This is
worth doing.

**Auditing.** The `access_matrix` output is a machine-readable summary of who has
what, suitable as evidence in an access review.

---

## 20. Known limitations and assumptions

1. **Group overage is not handled.** Beyond Entra's group claim limit, users lose
   access. See section 4.
2. **Azure RBAC for Kubernetes authorization is not supported.** The module
   creates Kubernetes RBAC objects, which that mode does not consult. It assumes
   Entra authentication combined with Kubernetes RBAC authorization.
3. **Only cluster-scoped and namespace-scoped bindings.** Per-resource-name
   grants are reachable only through `custom_roles` with `resource_names`.
4. **The chart's `externalSecret` mode fixes the Secret's key names.** They must
   be `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` and `OIDC_ISSUER_URL`.
5. **Single cluster per module instance.** Headlamp's multi-cluster mode is not
   configured here. Call the module once per cluster with the appropriate
   provider configuration.
6. **No NetworkPolicy, no certificate issuance, no DNS record.** Those depend on
   cluster-specific components the module does not assume.
7. **`service_account_name` collisions are not checked.** Supplying a name that
   already exists lets Helm fail rather than silently adopting the account.
8. **Verified against chart 0.45.0**, the version vendored at `charts/`. Values
   were read from that chart's own `values.yaml` and templates, and the module's
   generated values were rendered against it to confirm the resulting container
   arguments. A later chart may rename or remove values; check the release notes
   before bumping the pin.
9. **A vendored chart cannot be checksummed against the published digest**,
   because the digest covers the `.tgz` archive rather than an unpacked
   directory. Verify at download time, before unpacking.
10. **Not applied against a live cluster during authoring.** The configuration
    passes `terraform fmt`, `init` and `validate`, and the generated Helm values
    were rendered against the vendored chart and checked key by key. It has not
    been applied to a running AKS cluster in this session, so run
    `terraform plan` against a non-production cluster first.

---

## Inputs

See `variables.tf`; every variable carries a description, a type, and validation
where it is useful. The most commonly set ones:

| Name | Type | Default | Purpose |
| --- | --- | --- | --- |
| `headlamp_namespace` | string | `headlamp` | Target namespace |
| `create_namespace` | bool | `true` | Create it with the Kubernetes provider |
| `headlamp_use_local_chart` | bool | `true` | Install the chart vendored at `charts/` |
| `headlamp_chart_version` | string | `0.45.0` | Pinned version, checked against the vendored chart |
| `headlamp_chart_repository` | string | upstream repo | Used only when not installing locally |
| `headlamp_extra_values` | list(string) | `[]` | Raw YAML overrides |
| `headlamp_cluster_role_binding_enabled` | bool | `false` | Grant the Headlamp pod cluster permissions |
| `oidc_enabled` | bool | `true` | Enable OIDC sign-in |
| `oidc_client_id` | string | `null` | App Registration client ID |
| `oidc_client_secret` | string (sensitive) | `null` | Client secret, stored in state |
| `oidc_existing_secret_name` | string | `null` | Externally managed Secret, preferred |
| `oidc_issuer_url` | string | `null` | Entra v2.0 issuer |
| `oidc_scopes` | list(string) | AKS scope set | Requested scopes |
| `oidc_use_access_token` | bool | `true` | Required on AKS |
| `oidc_redirect_url` | string | `null` | Derived from the ingress host when null |
| `ingress_enabled` | bool | `false` | Create an Ingress |
| `ingress_class_name` | string | `null` | Your controller's class |
| `ingress_host` | string | `null` | Hostname |
| `ingress_tls_enabled` | bool | `true` | TLS block on the Ingress |
| `service_type` | string | `ClusterIP` | Service type |
| `rbac_enabled` | bool | `true` | Create RBAC objects |
| `rbac_groups` | map(object) | `{}` | Entra groups to authorise |
| `rbac_role_definitions` | map(object) | read/write/admin | Permission sets |
| `custom_roles` | map(object) | `{}` | Extra ClusterRoles |
| `namespace_roles` | map(object) | `{}` | Namespace-scoped Roles |

## Outputs

| Name | Purpose |
| --- | --- |
| `namespace`, `release_name`, `release_status`, `chart_version`, `app_version` | Deployment state |
| `chart_source` | Whether the chart came from `charts/` or from a repository |
| `service_name`, `service_port`, `service_type`, `port_forward_command` | Reaching Headlamp |
| `ingress_enabled`, `ingress_hostname`, `headlamp_url` | Ingress state |
| `oidc_enabled`, `oidc_redirect_url`, `oidc_secret_name`, `oidc_secret_managed_by_terraform` | OIDC configuration state, never credentials |
| `headlamp_service_account_has_cluster_role_binding` | Confirms the hardened default is in force |
| `cluster_role_names`, `namespace_role_names`, `cluster_role_binding_names`, `role_binding_names` | RBAC inventory |
| `access_matrix` | Who has what, where |

No output returns a client secret, a token or any other credential.
