###############################################################################
# helm.tf — the Velero install.
#
# Values are assembled as a structured object and yamlencoded, then optionally
# overridden by var.additional_helm_values. The release is configured for
# workload identity: credentials.useSecret = false, the service account is
# annotated with the identity client-id and labelled for the workload-identity
# webhook, and the BSL uses useAAD = "true" so the Azure plugin authenticates
# with the federated token instead of a storage key.
###############################################################################

locals {
  # Velero Schedule objects rendered into the chart's `schedules` map.
  velero_schedules = {
    for name, s in var.backup_schedules : name => {
      disabled = s.disabled
      schedule = s.schedule
      paused   = s.paused
      labels   = s.labels
      template = {
        ttl                      = s.ttl
        storageLocation          = s.storage_location
        includedNamespaces       = s.included_namespaces
        excludedNamespaces       = s.excluded_namespaces
        includedResources        = s.included_resources
        excludedResources        = s.excluded_resources
        snapshotVolumes          = s.snapshot_volumes
        defaultVolumesToFsBackup = s.default_volumes_to_fs_backup
        includeClusterResources  = s.include_cluster_resources
      }
    }
  }

  velero_values = {
    image = {
      repository = var.velero_image_repository
      tag        = var.velero_image_tag
    }

    # Azure object store + volume snapshotter plugin, loaded as an init container.
    initContainers = [
      {
        name            = "velero-plugin-for-microsoft-azure"
        image           = var.azure_plugin_image
        imagePullPolicy = "IfNotPresent"
        volumeMounts = [
          { mountPath = "/target", name = "plugins" }
        ]
      }
    ]

    # Workload identity: no static credentials secret.
    credentials = {
      useSecret = false
    }

    configuration = {
      uploaderType = var.uploader_type
      features     = var.enable_csi ? "EnableCSI" : ""

      backupStorageLocation = [
        {
          name     = "default"
          provider = "azure"
          bucket   = var.container_name
          default  = true
          config = {
            resourceGroup  = var.resource_group_name
            storageAccount = var.storage_account_name
            subscriptionId = var.subscription_id
            useAAD         = "true"
          }
        }
      ]

      volumeSnapshotLocation = [
        {
          name     = "default"
          provider = "azure"
          config = {
            subscriptionId = var.subscription_id
          }
        }
      ]
    }

    # Bind the server service account to the managed identity.
    serviceAccount = {
      server = {
        name = var.service_account_name
        annotations = {
          "azure.workload.identity/client-id" = azurerm_user_assigned_identity.velero.client_id
        }
        labels = {
          "azure.workload.identity/use" = "true"
        }
      }
    }

    podLabels = {
      "azure.workload.identity/use" = "true"
    }

    resources = {
      requests = var.server_resources.requests
      limits   = var.server_resources.limits
    }

    # File System Backup (kopia) for file-level backups of any volume.
    deployNodeAgent = var.deploy_node_agent
    nodeAgent = {
      podLabels = {
        "azure.workload.identity/use" = "true"
      }
      resources = {
        requests = var.node_agent_resources.requests
        limits   = var.node_agent_resources.limits
      }
    }

    defaultVolumesToFsBackup = var.default_volumes_to_fs_backup

    schedules = local.velero_schedules
  }

  # Module-computed values first, user overrides last (highest precedence).
  helm_values = compact([
    yamlencode(local.velero_values),
    var.additional_helm_values,
  ])
}

resource "helm_release" "velero" {
  count = var.install_velero ? 1 : 0

  name             = "velero"
  repository       = var.helm_repository
  chart            = "velero"
  version          = var.helm_chart_version
  namespace        = var.namespace
  create_namespace = true
  atomic           = true
  wait             = true
  timeout          = var.helm_timeout

  values = local.helm_values

  # Velero must not start until it can actually authenticate and reach storage.
  depends_on = [
    azurerm_federated_identity_credential.velero,
    azurerm_role_assignment.blob,
    azurerm_role_assignment.snapshot,
    azurerm_storage_container.this,
  ]
}
