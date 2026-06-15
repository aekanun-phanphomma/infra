# azure/velero — Enterprise Velero backup for AKS (Terraform)

Terraform that wraps [Velero](https://velero.io) to back up an **existing** AKS
cluster: Kubernetes API objects, PersistentVolumeClaims / PersistentVolumes,
Azure managed disks, and file contents of any volume (including Azure Files).

The product provisions everything Velero needs on Azure and installs the Velero
Helm chart wired for **Microsoft Entra Workload Identity** — no storage keys or
client secrets are ever written to the cluster.

## What gets created

- **Storage Account + private blob container** — the Velero `BackupStorageLocation`.
  Key-less (shared-key auth disabled), TLS 1.2+, geo-redundant, blob/container
  soft delete + versioning on.
- **User-assigned managed identity** + **federated identity credential** binding
  the Velero Kubernetes service account to that identity through the cluster's
  OIDC issuer.
- **Role assignments** (least privilege):
  - `Storage Blob Data Contributor` on the backup account.
  - `Contributor` (configurable) on the **AKS node resource group** (`MC_*`) and
    any extra disk resource groups — scoped, never subscription-wide — so Velero
    can create/delete managed-disk snapshots.
- **Velero Helm release**: Azure object-store + volume-snapshotter plugin, the
  `EnableCSI` feature flag for CSI disk snapshots, and the **node-agent**
  DaemonSet (kopia) for File System Backup.
- **Backup Schedules**: a daily snapshot backup (30-day TTL) and a weekly
  file-level backup (90-day TTL) by default; fully overridable.

## How each backup type is covered

| Target | Mechanism |
|--------|-----------|
| Cluster resources (K8s API objects) | Velero → blob container |
| PVC / PV (CSI disks) | CSI VolumeSnapshots (`EnableCSI`) → Azure disk snapshots |
| Azure managed disks | Azure plugin volume snapshotter |
| File contents / Azure Files | File System Backup (kopia) via node-agent → blob |

## Layout

```
velero/
├── versions.tf              # terraform + provider constraints (azurerm v4)
├── providers.tf             # azurerm / kubernetes / helm (kubelogin exec)
├── variables.tf             # clean root inputs
├── locals.tf                # subscription + node-RG scope resolution
├── main.tf                  # cluster data source, RG, module "velero"
├── outputs.tf
├── terraform.tfvars.example
├── tests/
│   ├── velero.tftest.hcl     # module unit tests (mocked providers)
│   └── root.tftest.hcl       # end-to-end product tests (mocked cluster)
└── modules/
    └── velero/               # reusable: storage + identity + rbac + helm
```

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # set cluster + storage names
terraform init
terraform test          # offline, mocked providers
terraform plan
terraform apply
```

> **First apply note:** the Kubernetes/Helm providers reach the cluster API
> server, so the runner needs network line-of-sight (VPN, bastion, or a
> self-hosted agent in the VNet for private clusters) and `kubelogin` on PATH.
> If that path is not ready yet, set `install_velero = false` for the first
> apply — the Azure resources are still created — then re-enable.

## Prerequisites on the cluster

- **OIDC issuer** and **Workload Identity** enabled (the AKS product in
  `../aks` enables both by default).
- For CSI snapshots: the Azure Disk CSI driver and the snapshot controller
  (enabled via the cluster `storage_profile`).

## Trigger an on-demand backup / restore

```bash
velero backup create adhoc-$(date +%s) --include-namespaces payments
velero backup get
velero restore create --from-backup adhoc-1700000000
```

## Requirements

| Name       | Version            |
|------------|--------------------|
| terraform  | >= 1.6.0           |
| azurerm    | >= 4.8.0, < 5.0.0  |
| helm       | >= 2.13.0, < 3.0.0 |
| kubernetes | >= 2.30.0, < 3.0.0 |

CLI tools on the runner: `az`, `kubelogin` (and `velero` for ad-hoc operations).
