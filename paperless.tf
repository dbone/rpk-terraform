resource "kubernetes_namespace" "paperless" {
  metadata {
    name = "paperless"
  }
}

resource "kubernetes_secret_v1" "paperless_secret" {
  metadata {
    name      = "paperless-secret"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }

  data = {
    PAPERLESS_SECRET_KEY     = var.PAPERLESS_SECRET_KEY
    PAPERLESS_REDIS_PASSWORD = var.PAPERLESS_REDIS_PASSWORD
    PAPERLESS_DBPASS         = var.PAPERLESS_DBPASS
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_v1" "paperless_data" {
  metadata {
    name = "paperless-data-pv"
  }
  spec {
    capacity           = { storage = "10Gi" }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/paperless/data"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "paperless_data" {
  metadata {
    name      = "paperless-data-pvc"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.paperless_data.metadata[0].name
    resources {
      requests = { storage = "10Gi" }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "paperless_media" {
  metadata {
    name = "paperless-media-pv"
  }
  spec {
    capacity           = { storage = "50Gi" }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/paperless/media"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "paperless_media" {
  metadata {
    name      = "paperless-media-pvc"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.paperless_media.metadata[0].name
    resources {
      requests = { storage = "50Gi" }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "paperless_export" {
  metadata {
    name = "paperless-export-pv"
  }
  spec {
    capacity           = { storage = "10Gi" }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/paperless/export"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "paperless_export" {
  metadata {
    name      = "paperless-export-pvc"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.paperless_export.metadata[0].name
    resources {
      requests = { storage = "10Gi" }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "paperless_consume" {
  metadata {
    name = "paperless-consume-pv"
  }
  spec {
    capacity           = { storage = "10Gi" }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/paperless/consume"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "paperless_consume" {
  metadata {
    name      = "paperless-consume-pvc"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.paperless_consume.metadata[0].name
    resources {
      requests = { storage = "10Gi" }
    }
  }
}

resource "kubernetes_deployment_v1" "gotenberg" {
  metadata {
    name      = "gotenberg"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "gotenberg"
      }
    }
    template {
      metadata {
        labels = {
          app                      = "gotenberg"
          "app.kubernetes.io/name" = "gotenberg"
        }
      }
      spec {
        container {
          name  = "gotenberg"
          image = "gotenberg/gotenberg:8"
          args  = ["gotenberg", "--chromium-disable-javascript=true", "--chromium-allow-list=file:///tmp/.*"]

          port {
            name           = "http"
            container_port = 3000
          }
        }

        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "gotenberg" {
  metadata {
    name      = "gotenberg"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }
  spec {
    selector = { app = "gotenberg" }
    port {
      name        = "http"
      port        = 3000
      target_port = 3000
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_deployment_v1" "tika" {
  metadata {
    name      = "tika"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "tika"
      }
    }
    template {
      metadata {
        labels = {
          app                      = "tika"
          "app.kubernetes.io/name" = "tika"
        }
      }
      spec {
        container {
          name  = "tika"
          image = "apache/tika:latest"

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
            container_port = 9998
          }
        }

        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "tika" {
  metadata {
    name      = "tika"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }
  spec {
    selector = { app = "tika" }
    port {
      name        = "http"
      port        = 9998
      target_port = 9998
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_deployment_v1" "paperless" {
  metadata {
    name      = "paperless"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "paperless"
      }
    }
    template {
      metadata {
        labels = {
          app                      = "paperless"
          "app.kubernetes.io/name" = "paperless"
        }
      }

      spec {
        container {
          name  = "paperless"
          image = "ghcr.io/paperless-ngx/paperless-ngx:latest"

          port {
            name           = "http"
            container_port = 8000
          }

          env {
            name  = "PAPERLESS_PORT"
            value = "8000"
          }

          env {
            name  = "USERMAP_UID"
            value = "1000"
          }

          env {
            name  = "USERMAP_GID"
            value = "1000"
          }

          env {
            name  = "PAPERLESS_OCR_LANGUAGE"
            value = "eng"
          }

          env {
            name  = "PAPERLESS_URL"
            value = "http://paperless.lan"
          }

          env {
            name = "PAPERLESS_SECRET_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.paperless_secret.metadata[0].name
                key  = "PAPERLESS_SECRET_KEY"
              }
            }
          }

          env {
            name  = "PAPERLESS_REDIS"
            value = "redis://:x5htm0u0mS3wHMR*@redis.redis.svc.cluster.local:6379"
          }

          env {
            name  = "PAPERLESS_DBENGINE"
            value = "mariadb"
          }

          env {
            name  = "PAPERLESS_DBHOST"
            value = "mariadb.mariadb.svc.cluster.local"
          }

          env {
            name  = "PAPERLESS_DBPORT"
            value = "3306"
          }

          env {
            name  = "PAPERLESS_DBNAME"
            value = "paperless"
          }

          env {
            name  = "PAPERLESS_DBUSER"
            value = "paperless"
          }

          env {
            name = "PAPERLESS_DBPASS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.paperless_secret.metadata[0].name
                key  = "PAPERLESS_DBPASS"
              }
            }
          }

          env {
            name  = "PAPERLESS_TIKA_ENABLED"
            value = "1"
          }

          env {
            name  = "PAPERLESS_TIKA_GOTENBERG_ENDPOINT"
            value = "http://gotenberg.paperless.svc.cluster.local:3000"
          }

          env {
            name  = "PAPERLESS_TIKA_ENDPOINT"
            value = "http://tika.paperless.svc.cluster.local:9998"
          }

          volume_mount {
            name       = "paperless-data"
            mount_path = "/usr/src/paperless/data"
          }

          volume_mount {
            name       = "paperless-media"
            mount_path = "/usr/src/paperless/media"
          }

          volume_mount {
            name       = "paperless-export"
            mount_path = "/usr/src/paperless/export"
          }

          volume_mount {
            name       = "paperless-consume"
            mount_path = "/usr/src/paperless/consume"
          }
        }

        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        volume {
          name = "paperless-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.paperless_data.metadata[0].name
          }
        }

        volume {
          name = "paperless-media"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.paperless_media.metadata[0].name
          }
        }

        volume {
          name = "paperless-export"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.paperless_export.metadata[0].name
          }
        }

        volume {
          name = "paperless-consume"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.paperless_consume.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "paperless" {
  metadata {
    name      = "paperless"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }

  spec {
    selector = {
      app = "paperless"
    }

    port {
      name        = "http"
      port        = 8000
      target_port = 8000
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "paperless" {
  metadata {
    name      = "paperless-ingress"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "paperless.lan"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.paperless.metadata[0].name
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }
}
