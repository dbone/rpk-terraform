resource "kubernetes_namespace" "pgadmin" {
  metadata {
    name = "pgadmin"
  }
}

resource "kubernetes_secret_v1" "pgadmin_secret" {
  metadata {
    name      = "pgadmin-secret"
    namespace = kubernetes_namespace.pgadmin.metadata[0].name
  }

  data = {
    PGADMIN_DEFAULT_EMAIL    = var.PGADMIN_DEFAULT_EMAIL
    PGADMIN_DEFAULT_PASSWORD = var.PGADMIN_DEFAULT_PASSWORD
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_v1" "pgadmin_data" {
  metadata {
    name = "pgadmin-data-pv"
  }

  spec {
    capacity = {
      storage = "5Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"

    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/postgres/pgadmin_data"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "pgadmin_data" {
  metadata {
    name      = "pgadmin-data-pvc"
    namespace = kubernetes_namespace.pgadmin.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.pgadmin_data.metadata[0].name

    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "pgadmin" {
  metadata {
    name      = "pgadmin"
    namespace = kubernetes_namespace.pgadmin.metadata[0].name
    labels = {
      app = "pgadmin"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "pgadmin"
      }
    }

    template {
      metadata {
        labels = {
          app                      = "pgadmin"
          "app.kubernetes.io/name" = "pgadmin"
        }
      }

      spec {
        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        container {
          name  = "pgadmin"
          image = "dpage/pgadmin4:latest"

          resources {
            requests = {
              cpu    = "100m"  # 0.1 CPU core (100 millicores)
              memory = "256Mi" # Baseline reserved RAM
            }
            limits = {
              cpu    = "1000m" # 1.0 CPU core burst cap
              memory = "1Gi"   # Hard RAM ceiling before OOMKill
            }
          }

          port {
            name           = "http"
            container_port = 80
          }

          env {
            name = "PGADMIN_DEFAULT_EMAIL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.pgadmin_secret.metadata[0].name
                key  = "PGADMIN_DEFAULT_EMAIL"
              }
            }
          }

          env {
            name = "PGADMIN_DEFAULT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.pgadmin_secret.metadata[0].name
                key  = "PGADMIN_DEFAULT_PASSWORD"
              }
            }
          }

          # Disable enhanced CSRF session protection behind local reverse proxies if needed
          env {
            name  = "PGADMIN_LISTEN_PORT"
            value = "80"
          }

          volume_mount {
            name       = "pgadmin-storage"
            mount_path = "/var/lib/pgadmin"
          }
        }

        volume {
          name = "pgadmin-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.pgadmin_data.metadata[0].name
          }
        }
      }
    }
  }
}

# 6. ClusterIP Service (Port 80)
resource "kubernetes_service_v1" "pgadmin" {
  metadata {
    name      = "pgadmin"
    namespace = kubernetes_namespace.pgadmin.metadata[0].name
  }

  spec {
    selector = {
      app = "pgadmin"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

# 7. Ingress Route (http://pgadmin.lan via Traefik)
resource "kubernetes_ingress_v1" "pgadmin" {
  metadata {
    name      = "pgadmin-ingress"
    namespace = kubernetes_namespace.pgadmin.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "pgadmin.lan"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.pgadmin.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
