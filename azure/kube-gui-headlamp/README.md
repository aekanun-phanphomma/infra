# Headlamp on AKS

A reusable Terraform module that deploys the [Headlamp](https://headlamp.dev/)
Kubernetes UI into an existing AKS cluster, authenticates users against
Microsoft Entra ID, and maps Entra groups to Kubernetes RBAC.

Headlamp replaces the retired Kubernetes Dashboard. It is a GUI only: every
authorisation decision is made by the Kubernetes API server against the RBAC
objects this module creates, not by Headlamp.

## Layout

```text
modules/
└── headlamp/              reusable module, no provider configuration
    ├── main.tf            namespace, OIDC secret, Helm release
    ├── rbac.tf            ClusterRoles, Roles, bindings to Entra groups
    ├── locals.tf          chart source, OIDC wiring, Helm values, RBAC flattening
    ├── variables.tf       inputs
    ├── outputs.tf         outputs
    ├── versions.tf        Terraform and provider constraints
    ├── README.md          full documentation
    └── charts/            the Headlamp chart, vendored and installed from here

aks-headlamp/              a caller, kept entirely separate from the module
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
└── README.md
```

## Chart source

The chart is vendored at `modules/headlamp/charts` and installed from there by
default, so `terraform apply` needs no access to the public chart repository and
the chart that was reviewed is the chart that gets installed.

The declared `headlamp_chart_version` is checked against the vendored chart's
`Chart.yaml` before anything is installed, so the two cannot drift apart
silently. Set `headlamp_use_local_chart = false` to pull from the repository
instead.

## Scope boundary

This module does **not** create or manage the Microsoft Entra App Registration or
Enterprise Application. It also creates no client secret, no Graph or API
permission, no admin consent, no Entra group, and no AKS cluster. Those are
owned outside Terraform, and their values are passed in as variables.

See section 5 of the [module README](modules/headlamp/README.md) for exactly what
has to exist first.

## Quick start

```bash
cd aks-headlamp
cp terraform.tfvars.example terraform.tfvars   # then edit it
terraform init
terraform plan
terraform apply
```

## Verified against

| Component | Version |
| --- | --- |
| Headlamp Helm chart | 0.45.0 |
| `hashicorp/helm` | 3.3.0 |
| `hashicorp/kubernetes` | 3.2.1 |
| Terraform | 1.15.6 |

Chart values were read from the vendored chart's own `values.yaml` and
templates. Provider arguments were read from the provider documentation at the
pinned tags. The module's generated values were rendered against the vendored
chart and the resulting container arguments were checked. Nothing here was
applied to a live cluster, so run a plan against a non-production cluster first.
