resource "kubernetes_namespace" "open_webui" {
  metadata {
    name = "open-webui"
  }
}

resource "kubernetes_persistent_volume_v1" "open_webui_data" {
  metadata {
    name = "open-webui-data-pv"
  }

  spec {
    capacity = {
      storage = "10Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"

    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/open-webui/data"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "open_webui_data" {
  metadata {
    name      = "open-webui-data-pvc"
    namespace = kubernetes_namespace.open_webui.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "local-path"

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "open_webui" {
  metadata {
    name      = "open-webui"
    namespace = kubernetes_namespace.open_webui.metadata[0].name
    labels = {
      app = "open-webui"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "open-webui"
      }
    }

    template {
      metadata {
        labels = {
          app                      = "open-webui"
          "app.kubernetes.io/name" = "open-webui"
        }
      }

      spec {
        container {
          name  = "open-webui"
          image = "ghcr.io/open-webui/open-webui:main"

          port {
            name           = "http"
            container_port = 8080
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "2000m"
              memory = "2Gi"
            }
          }

          env {
            name  = "OLLAMA_BASE_URL"
            value = "http://studio.lan:11434"
          }

          env {
            name  = "ENABLE_SIGNUP"
            value = "true"
          }

          env {
            name  = "WEBUI_URL"
            value = "http://open-webui.lan"
          }

          env {
            name  = "CORS_ALLOW_ORIGIN"
            value = "http://open-webui.lan"
          }

          env {
            name  = "RAG_EMBEDDING_ENGINE"
            value = "ollama"
          }

          env {
            name  = "RAG_OLLAMA_BASE_URL"
            value = "http://studio.lan:11434"
          }

          env {
            name  = "RAG_EMBEDDING_MODEL"
            value = "nomic-embed-text"
          }

          volume_mount {
            name       = "open-webui-storage"
            mount_path = "/app/backend/data"
          }
        }

        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        volume {
          name = "open-webui-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.open_webui_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "open_webui" {
  metadata {
    name      = "open-webui"
    namespace = kubernetes_namespace.open_webui.metadata[0].name
  }

  spec {
    selector = {
      app = "open-webui"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "open_webui" {
  metadata {
    name      = "open-webui-ingress"
    namespace = kubernetes_namespace.open_webui.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "open-webui.lan"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.open_webui.metadata[0].name
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
