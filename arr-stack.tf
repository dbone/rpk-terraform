resource "kubernetes_namespace" "arr_stack" {
  metadata {
    name = "arr-stack"
  }
}

resource "kubernetes_secret_v1" "arr_secrets" {
  metadata {
    name      = "arr-db-secrets"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }

  data = {
    SONARR_DB_PASSWORD = var.SONARR_DB_PASSWORD
    RADARR_DB_PASSWORD = var.RADARR_DB_PASSWORD
    LIDARR_DB_PASSWORD = var.LIDARR_DB_PASSWORD
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_v1" "arr_interchange" {
  metadata { name = "arr-interchange-pv" }
  spec {
    capacity           = { storage = "1024Gi" }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/arr"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "arr_interchange" {
  metadata {
    name      = "arr-interchange-pvc"
    namespace = "arr-stack"
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.arr_interchange.metadata[0].name
    resources { requests = { storage = "1024Gi" } }
  }
}
