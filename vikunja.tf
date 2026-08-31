resource "kubernetes_namespace" "vikunja" {
  metadata {
    name = "vikunja"
  }
}

resource "kubernetes_secret_v1" "vikunja_secret" {
  metadata {
    name      = "vikunja-secret"
    namespace = kubernetes_namespace.vikunja.metadata[0].name
  }

  data = {
    VIKUNJA_DATABASE_PASSWORD = var.VIKUNJA_DATABASE_PASSWORD
    VIKUNJA_SERVICE_SECRET    = var.VIKUNJA_SERVICE_SECRET
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_v1" "vikunja_files" {
  metadata {
    name = "vikunja-files-pv"
  }

  spec {
    capacity = {
      storage = "10Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"

    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/vikunja/files"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "vikunja_files" {
  metadata {
    name      = "vikunja-files-pvc"
    namespace = kubernetes_namespace.vikunja.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.vikunja_files.metadata[0].name

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "vikunja" {
  metadata {
    name      = "vikunja"
    namespace = kubernetes_namespace.vikunja.metadata[0].name
    labels = {
      app = "vikunja"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "vikunja"
      }
    }

    template {
      metadata {
        labels = {
          app                      = "vikunja"
          "app.kubernetes.io/name" = "vikunja"
        }
      }

      spec {
        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        container {
          name  = "vikunja"
          image = "vikunja/vikunja:latest"

          port {
            name           = "http"
            container_port = 3456
          }

          env {
            name  = "VIKUNJA_DATABASE_TYPE"
            value = "postgres"
          }

          env {
            name  = "VIKUNJA_DATABASE_HOST"
            value = "postgres.postgres.svc.cluster.local:5432"
          }

          env {
            name  = "VIKUNJA_DATABASE_DATABASE"
            value = "vikunja"
          }

          env {
            name  = "VIKUNJA_DATABASE_USER"
            value = "vikunja"
          }

          env {
            name = "VIKUNJA_DATABASE_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.vikunja_secret.metadata[0].name
                key  = "VIKUNJA_DATABASE_PASSWORD"
              }
            }
          }

          env {
            name  = "VIKUNJA_SERVICE_PUBLICURL"
            value = "http://vikunja.lan/"
          }

          env {
            name = "VIKUNJA_SERVICE_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.vikunja_secret.metadata[0].name
                key  = "VIKUNJA_SERVICE_SECRET"
              }
            }
          }

          env {
            name  = "VIKUNJA_SERVICE_ENABLEREGISTRATION"
            value = "true"
          }

          # CORS & Allowed Origins for both HTTP and HTTPS
          env {
            name  = "VIKUNJA_CORS_ENABLE"
            value = "true"
          }

          env {
            name  = "VIKUNJA_CORS_ORIGINS"
            value = "http://vikunja.lan,https://vikunja.lan"
          }

          env {
            name  = "VIKUNJA_SERVICE_ALLOWEDORIGINS"
            value = "http://vikunja.lan,https://vikunja.lan"
          }

          env {
            name  = "VIKUNJA_FILES_BASEPATH"
            value = "/app/vikunja/files"
          }

          volume_mount {
            name       = "vikunja-files"
            mount_path = "/app/vikunja/files"
          }
        }

        volume {
          name = "vikunja-files"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.vikunja_files.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "vikunja" {
  metadata {
    name      = "vikunja"
    namespace = kubernetes_namespace.vikunja.metadata[0].name
  }

  spec {
    selector = {
      app = "vikunja"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 3456
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "vikunja" {
  metadata {
    name      = "vikunja-ingress"
    namespace = kubernetes_namespace.vikunja.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = ["vikunja.lan"]
      secret_name = "vikunja-tls-cert"
    }

    rule {
      host = "vikunja.lan"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.vikunja.metadata[0].name
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
