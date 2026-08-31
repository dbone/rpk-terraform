resource "kubernetes_namespace" "mealie" {
  metadata {
    name = "mealie"
  }
}

resource "kubernetes_persistent_volume_v1" "mealie_data" {
  metadata {
    name = "mealie-data-pv"
  }

  spec {
    capacity = {
      storage = "10Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"

    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/mealie/data"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "mealie_data" {
  metadata {
    name      = "mealie-data-pvc"
    namespace = kubernetes_namespace.mealie.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.mealie_data.metadata[0].name

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "mealie" {
  metadata {
    name      = "mealie"
    namespace = kubernetes_namespace.mealie.metadata[0].name
    labels = {
      app = "mealie"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mealie"
      }
    }

    template {
      metadata {
        labels = {
          app                      = "mealie"
          "app.kubernetes.io/name" = "mealie"
        }
      }

      spec {
        container {
          name  = "mealie"
          image = "ghcr.io/mealie-recipes/mealie:latest"

          port {
            name           = "http"
            container_port = 9000
          }

          env {
            name  = "ALLOW_SIGNUP"
            value = "true"
          }

          env {
            name  = "TZ"
            value = "America/New_York"
          }

          env {
            name  = "PUID"
            value = "1000"
          }

          env {
            name  = "PGID"
            value = "1000"
          }

          env {
            name  = "BASE_URL"
            value = "http://mealie.lan"
          }

          env {
            name  = "OPENAI_BASE_URL"
            value = "http://studio.lan:11434/v1"
          }

          env {
            name  = "OPENAI_API_KEY"
            value = "ollama"
          }

          env {
            name  = "OPENAI_MODEL"
            value = "qwen3:14b"
          }

          volume_mount {
            name       = "mealie-storage"
            mount_path = "/app/data"
          }
        }

        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        volume {
          name = "mealie-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.mealie_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "mealie" {
  metadata {
    name      = "mealie"
    namespace = kubernetes_namespace.mealie.metadata[0].name
  }

  spec {
    selector = {
      app = "mealie"
    }

    port {
      name        = "http"
      port        = 9000
      target_port = 9000
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "mealie" {
  metadata {
    name      = "mealie-ingress"
    namespace = kubernetes_namespace.mealie.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "mealie.lan"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.mealie.metadata[0].name
              port {
                number = 9000
              }
            }
          }
        }
      }
    }
  }
}
