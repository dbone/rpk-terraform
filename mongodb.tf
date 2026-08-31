resource "kubernetes_namespace" "mongodb" {
  metadata {
    name = "mongodb"
  }
}

resource "kubernetes_secret_v1" "mongodb_secret" {
  metadata {
    name      = "mongodb-secret"
    namespace = kubernetes_namespace.mongodb.metadata[0].name
  }

  data = {
    MONGO_INITDB_ROOT_USERNAME = var.MONGO_INITDB_ROOT_USERNAME
    MONGO_INITDB_ROOT_PASSWORD = var.MONGO_INITDB_ROOT_PASSWORD
  }

  type = "Opaque"
}

# 3. PersistentVolume pointing to the autofs NFS path
resource "kubernetes_persistent_volume_v1" "mongodb_data" {
  metadata {
    name = "mongodb-data-pv"
  }

  spec {
    capacity = {
      storage = "10Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"

    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/mongodb/data"
        type = "DirectoryOrCreate"
      }
    }
  }
}

# 4. PersistentVolumeClaim
resource "kubernetes_persistent_volume_claim_v1" "mongodb_data" {
  metadata {
    name      = "mongodb-data-pvc"
    namespace = kubernetes_namespace.mongodb.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.mongodb_data.metadata[0].name

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

# 5. MongoDB Deployment
resource "kubernetes_deployment_v1" "mongodb" {
  metadata {
    name      = "mongodb"
    namespace = kubernetes_namespace.mongodb.metadata[0].name
    labels = {
      app = "mongodb"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mongodb"
      }
    }

    template {
      metadata {
        labels = {
          app = "mongodb"
        }
      }

      spec {
        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }
        container {
          name  = "mongodb"
          image = "mongo:4.4.18"
          #image = "mongo:latest"

          port {
            name           = "mongodb"
            container_port = 27017
          }

          env {
            name = "MONGO_INITDB_ROOT_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mongodb_secret.metadata[0].name
                key  = "MONGO_INITDB_ROOT_USERNAME"
              }
            }
          }

          env {
            name = "MONGO_INITDB_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mongodb_secret.metadata[0].name
                key  = "MONGO_INITDB_ROOT_PASSWORD"
              }
            }
          }

          # Standard MongoDB database directory
          volume_mount {
            name       = "mongodb-storage"
            mount_path = "/data/db"
          }
        }

        volume {
          name = "mongodb-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.mongodb_data.metadata[0].name
          }
        }
      }
    }
  }
}

# 6. ClusterIP Service (Internal cluster network access)
resource "kubernetes_service_v1" "mongodb" {
  metadata {
    name      = "mongodb"
    namespace = kubernetes_namespace.mongodb.metadata[0].name
  }

  spec {
    selector = {
      app = "mongodb"
    }

    port {
      name        = "mongodb"
      port        = 27017
      target_port = 27017
    }

    type = "ClusterIP"
  }
}
