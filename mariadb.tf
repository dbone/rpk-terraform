resource "kubernetes_namespace" "mariadb" {
  metadata {
    name = "mariadb"
  }
}

resource "kubernetes_secret_v1" "mariadb_secret" {
  metadata {
    name      = "mariadb-secret"
    namespace = kubernetes_namespace.mariadb.metadata[0].name
  }

  data = {
    MYSQL_ROOT_PASSWORD = var.MYSQL_ROOT_PASSWORD
    APP_MYSQL_PASSWORD  = var.APP_MYSQL_PASSWORD
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_v1" "mariadb_data" {
  metadata {
    name = "mariadb-data-pv"
  }

  spec {
    capacity = {
      storage = "10Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"

    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/mariadb/data"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "mariadb_data" {
  metadata {
    name      = "mariadb-data-pvc"
    namespace = kubernetes_namespace.mariadb.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.mariadb_data.metadata[0].name

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "mariadb" {
  metadata {
    name      = "mariadb"
    namespace = kubernetes_namespace.mariadb.metadata[0].name
    labels = {
      app = "mariadb"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mariadb"
      }
    }

    template {
      metadata {
        labels = {
          app = "mariadb"
        }
      }

      spec {
        container {
          name  = "mariadb"
          image = "mariadb:latest"

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "1Gi"
            }
          }

          port {
            name           = "mysql"
            container_port = 3306
          }

          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mariadb_secret.metadata[0].name
                key  = "MYSQL_ROOT_PASSWORD"
              }
            }
          }

          env {
            name  = "MYSQL_DATABASE"
            value = "app_default_db"
          }

          env {
            name  = "MYSQL_USER"
            value = "app_user"
          }

          env {
            name = "APP_MYSQL_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mariadb_secret.metadata[0].name
                key  = "APP_MYSQL_PASSWORD"
              }
            }
          }

          volume_mount {
            name       = "mariadb-storage"
            mount_path = "/var/lib/mysql"
          }
        }

        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        volume {
          name = "mariadb-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.mariadb_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "mariadb" {
  metadata {
    name      = "mariadb"
    namespace = kubernetes_namespace.mariadb.metadata[0].name
  }

  spec {
    selector = {
      app = "mariadb"
    }

    port {
      name        = "mysql"
      port        = 3306
      target_port = 3306
    }

    type = "ClusterIP"
  }
}
