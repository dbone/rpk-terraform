resource "kubernetes_namespace" "n8n" {
  metadata {
    name = "n8n"
  }
}

resource "kubernetes_secret_v1" "n8n_secret" {
  metadata {
    name      = "n8n-secret"
    namespace = kubernetes_namespace.n8n.metadata[0].name
  }

  data = {
    DB_POSTGRESDB_PASSWORD = var.DB_POSTGRESDB_PASSWORD
    N8N_ENCRYPTION_KEY     = var.N8N_ENCRYPTION_KEY
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_v1" "n8n_data" {
  metadata {
    name = "n8n-data-pv"
  }

  spec {
    capacity = {
      storage = "10Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"

    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/n8n/data"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "n8n_data" {
  metadata {
    name      = "n8n-data-pvc"
    namespace = kubernetes_namespace.n8n.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.n8n_data.metadata[0].name

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "n8n" {
  metadata {
    name      = "n8n"
    namespace = kubernetes_namespace.n8n.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "n8n"
      }
    }

    template {
      metadata {
        labels = {
          app                      = "n8n"
          "app.kubernetes.io/name" = "n8n"
        }
      }

      spec {
        container {
          name  = "n8n"
          image = "n8nio/n8n:latest"

          port {
            name           = "http"
            container_port = 5678
          }

          env {
            name  = "DB_TYPE"
            value = "postgresdb"
          }

          env {
            name  = "DB_POSTGRESDB_HOST"
            value = "postgres.postgres.svc.cluster.local"
          }

          env {
            name  = "DB_POSTGRESDB_PORT"
            value = "5432"
          }

          env {
            name  = "DB_POSTGRESDB_DATABASE"
            value = "n8n"
          }

          env {
            name  = "DB_POSTGRESDB_USER"
            value = "n8n"
          }

          env {
            name = "DB_POSTGRESDB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.n8n_secret.metadata[0].name
                key  = "DB_POSTGRESDB_PASSWORD"
              }
            }
          }

          env {
            name  = "N8N_HOST"
            value = "n8n.lan"
          }

          env {
            name  = "N8N_PORT"
            value = "5678"
          }

          env {
            name  = "N8N_PROTOCOL"
            value = "http"
          }

          env {
            name  = "N8N_EDITOR_BASE_URL"
            value = "http://n8n.lan/"
          }

          env {
            name  = "WEBHOOK_URL"
            value = "http://n8n.lan/"
          }

          env {
            name  = "GENERIC_TIMEZONE"
            value = "America/New_York"
          }

          env {
            name  = "N8N_DIAGNOSTICS_ENABLED"
            value = "false"
          }

          env {
            name = "N8N_ENCRYPTION_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.n8n_secret.metadata[0].name
                key  = "N8N_ENCRYPTION_KEY"
              }
            }
          }

          volume_mount {
            name       = "n8n-storage"
            mount_path = "/home/node/.n8n"
          }
        }

        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        volume {
          name = "n8n-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.n8n_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "n8n" {
  metadata {
    name      = "n8n"
    namespace = kubernetes_namespace.n8n.metadata[0].name
  }

  spec {
    selector = {
      app = "n8n"
    }

    port {
      name        = "http"
      port        = 5678
      target_port = 5678
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "n8n" {
  metadata {
    name      = "n8n-ingress"
    namespace = kubernetes_namespace.n8n.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "n8n.lan"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.n8n.metadata[0].name
              port {
                number = 5678
              }
            }
          }
        }
      }
    }
  }
}
