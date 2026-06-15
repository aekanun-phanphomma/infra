# azure/aks — Enterprise AKS (Terraform)

Private, hardened Azure Kubernetes Service built from two reusable modules and a
numbered root layout. The modules expose (almost) the entire surface of the
underlying `azurerm` resources — even arguments the default root config does not
set — so any feature available in the Azure portal can be expressed in code.

## Layout

```
aks/
├── versions.tf              # terraform + provider constraints (azurerm v4)
├── providers.tf             # azurerm / azuread / kubernetes / helm (kubelogin exec)
├── variables.tf             # clean root inputs
├── locals.tf                # naming + resolved IDs
├── 00-foundation.tf         # RG, identity, Log Analytics, Key Vault + DES (CMK)
├── 01-cluster.tf            # module "aks_cluster"   — control plane + system pool
├── 02-nodepool.tf           # module "aks_nodepool"  — user/workload pool
├── 03-helm.tf               # istio-base → istiod, external-dns
├── outputs.tf
├── terraform.tfvars.example
├── tests/                   # native `terraform test` suites (mocked providers)
│   ├── cluster.tftest.hcl
│   └── nodepool.tftest.hcl
└── modules/
    ├── aks-cluster/         # azurerm_kubernetes_cluster (full feature set)
    └── aks-nodepool/        # azurerm_kubernetes_cluster_node_pool (full set)
```

## What the default configuration enables

- **Private cluster** with AKS-managed private DNS zone.
- **Customer-managed disk encryption** via Key Vault + Disk Encryption Set, plus
  host-based encryption on every node pool.
- **Entra ID (AAD) RBAC** with Azure RBAC and local accounts disabled.
- **Workload Identity** + OIDC issuer.
- **Azure CNI overlay** with the Cilium data plane and network policy.
- **Key Vault Secrets Provider** (CSI) with rotation, **KEDA**, **Azure Policy**,
  **Container Insights** + managed Prometheus metrics.
- **Cluster autoscaler** on both system and user pools; `node_count` drift is
  ignored so the autoscaler owns sizing.
- **Automatic upgrades** (stable channel) and node-image OS upgrades.

## Module feature coverage

`aks-cluster` wires through: cluster config, default node pool (incl.
`kubelet_config`, `linux_os_config`/`sysctl`, `node_network_profile`), dynamic
upgrade settings, autoscaler profile, disk encryption (DES + KMS etcd), private
API server + `api_server_access_profile`, managed Istio service mesh, identity /
service principal, storage profile, Key Vault secrets provider, network profile
(load balancer / NAT gateway), AAD RBAC, workload identity, maintenance windows,
and every add-on (AGIC, ACI connector, Defender, OMS, web app routing, confidential
computing, image cleaner, etc.).

`aks-nodepool` wires through: name, version, size, disk, subnet, scaling, spot,
taints/labels, upgrade settings, `kubelet_config`, `linux_os_config`,
`node_network_profile`, Windows profile, and a toggle to ignore `node_count`
changes for autoscaler-owned pools.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # edit subnet IDs, admin groups…
terraform init
terraform test          # offline, mocked providers
terraform plan
terraform apply
```

> **First apply note:** the Kubernetes/Helm providers reach the **private** API
> server, so the runner needs network line-of-sight (VPN, bastion, self-hosted
> agent in the VNet) and `kubelogin` on PATH. If that path is not ready yet, set
> `enable_helm_releases = false` for the first apply and re-enable afterwards.

## Requirements

| Name       | Version            |
|------------|--------------------|
| terraform  | >= 1.6.0           |
| azurerm    | >= 4.0.0, < 5.0.0  |
| azuread    | >= 2.50.0          |
| helm       | >= 2.13.0, < 3.0.0 |
| kubernetes | >= 2.30.0, < 3.0.0 |

CLI tools on the runner: `az`, `kubelogin`.
