resource "kubernetes_namespace" "readeck" {
  metadata {
    name = "readeck"
  }
}

resource "kubernetes_persistent_volume_v1" "readeck_data" {
  metadata {
    name = "readeck-data-pv"
  }

  spec {
    capacity = {
      storage = "5Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"

    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/readeck/data"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "readeck_data" {
  metadata {
    name      = "readeck-data-pvc"
    namespace = kubernetes_namespace.readeck.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.readeck_data.metadata[0].name

    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "readeck" {
  metadata {
    name      = "readeck"
    namespace = kubernetes_namespace.readeck.metadata[0].name
    labels = {
      app = "readeck"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "readeck"
      }
    }

    template {
      metadata {
        labels = {
          app                      = "readeck"
          "app.kubernetes.io/name" = "readeck"
        }
      }

      spec {
        security_context {
          run_as_user     = 1000
          run_as_group    = 1000
          fs_group        = 1000
          run_as_non_root = true
        }

        container {
          name  = "readeck"
          image = "codeberg.org/readeck/readeck:latest"

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
            container_port = 8000
          }

          env {
            name  = "READECK_SERVER_HOST"
            value = "0.0.0.0"
          }

          env {
            name  = "READECK_SERVER_PORT"
            value = "8000"
          }

          volume_mount {
            name       = "readeck-storage"
            mount_path = "/readeck"
          }
        }

        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        volume {
          name = "readeck-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.readeck_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "readeck" {
  metadata {
    name      = "readeck"
    namespace = kubernetes_namespace.readeck.metadata[0].name
  }

  spec {
    selector = {
      app = "readeck"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 8000
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "readeck" {
  metadata {
    name      = "readeck-ingress"
    namespace = kubernetes_namespace.readeck.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "readeck.lan"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.readeck.metadata[0].name
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
