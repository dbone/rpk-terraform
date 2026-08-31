resource "kubernetes_namespace" "librechat" {
  metadata {
    name = "librechat"
  }
}

resource "kubernetes_secret_v1" "librechat_secret" {
  metadata {
    name      = "librechat-secret"
    namespace = kubernetes_namespace.librechat.metadata[0].name
  }

  data = {
    MONGO_URI          = var.MONGO_URI
    JWT_SECRET         = var.JWT_SECRET
    JWT_REFRESH_SECRET = var.JWT_REFRESH_SECRET
    CREDS_KEY          = var.CREDS_KEY
    CREDS_IV           = var.CREDS_IV
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_v1" "librechat_config" {
  metadata {
    name = "librechat-config-pv"
  }

  spec {
    capacity = {
      storage = "5Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"

    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/librechat/config"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "librechat_config" {
  metadata {
    name      = "librechat-config-pvc"
    namespace = kubernetes_namespace.librechat.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.librechat_config.metadata[0].name

    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "librechat" {
  metadata {
    name      = "librechat"
    namespace = kubernetes_namespace.librechat.metadata[0].name
    labels = {
      app = "librechat"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "librechat"
      }
    }

    template {
      metadata {
        labels = {
          app                      = "librechat"
          "app.kubernetes.io/name" = "librechat"
        }
      }

      spec {
        container {
          name  = "librechat"
          image = "ghcr.io/danny-avila/librechat-dev-api:latest"

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
            name           = "http"
            container_port = 3080
          }

          env {
            name  = "HOST"
            value = "0.0.0.0"
          }

          env {
            name  = "PORT"
            value = "3080"
          }

          env {
            name  = "DOMAIN_CLIENT"
            value = "http://librechat.lan"
          }

          env {
            name  = "DOMAIN_SERVER"
            value = "http://librechat.lan"
          }

          env {
            name  = "ALLOW_REGISTRATION"
            value = "true"
          }

          env {
            name  = "ALLOW_EMAIL_LOGIN"
            value = "true"
          }

          env {
            name = "MONGO_URI"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.librechat_secret.metadata[0].name
                key  = "MONGO_URI"
              }
            }
          }

          env {
            name = "JWT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.librechat_secret.metadata[0].name
                key  = "JWT_SECRET"
              }
            }
          }

          env {
            name = "JWT_REFRESH_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.librechat_secret.metadata[0].name
                key  = "JWT_REFRESH_SECRET"
              }
            }
          }

          env {
            name = "CREDS_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.librechat_secret.metadata[0].name
                key  = "CREDS_KEY"
              }
            }
          }

          env {
            name = "CREDS_IV"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.librechat_secret.metadata[0].name
                key  = "CREDS_IV"
              }
            }
          }

          # Mounts librechat.yaml from the persistent storage volume
          volume_mount {
            name       = "librechat-storage"
            mount_path = "/app/librechat.yaml"
            sub_path   = "librechat.yaml"
          }
        }

        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        volume {
          name = "librechat-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.librechat_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "librechat" {
  metadata {
    name      = "librechat"
    namespace = kubernetes_namespace.librechat.metadata[0].name
  }

  spec {
    selector = {
      app = "librechat"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 3080
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "librechat" {
  metadata {
    name      = "librechat-ingress"
    namespace = kubernetes_namespace.librechat.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "librechat.lan"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.librechat.metadata[0].name
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
