resource "kubernetes_namespace" "homepage" {
  metadata {
    name = "homepage"
  }
}

resource "kubernetes_persistent_volume_v1" "homepage_config" {
  metadata {
    name = "homepage-config-pv"
  }
  spec {
    capacity = {
      storage = "1Gi"
    }
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "nfs-manual"

    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/homepage/config"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "homepage_images" {
  metadata {
    name = "homepage-images-pv"
  }
  spec {
    capacity = {
      storage = "1Gi"
    }
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "nfs-manual"

    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/homepage/images"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "homepage_config" {
  metadata {
    name      = "homepage-config-pvc"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.homepage_config.metadata[0].name
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "homepage_images" {
  metadata {
    name      = "homepage-images-pvc"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.homepage_images.metadata[0].name
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "homepage" {
  metadata {
    name      = "homepage"
    namespace = kubernetes_namespace.homepage.metadata[0].name
    labels = {
      app = "homepage"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "homepage"
      }
    }

    template {
      metadata {
        labels = {
          app = "homepage"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.homepage.metadata[0].name

        container {
          name  = "homepage"
          image = "ghcr.io/gethomepage/homepage:latest"

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
            container_port = 3000
            name           = "http"
          }

          env {
            name  = "HOMEPAGE_ALLOWED_HOSTS"
            value = "homepage.lan,homepage.lan:80,homepage.lan:3000,localhost,127.0.0.1,*"
          }

          env {
            name  = "LOG_LEVEL"
            value = "debug"
          }

          volume_mount {
            name       = "config-storage"
            mount_path = "/app/config"
          }

          volume_mount {
            name       = "config-images"
            mount_path = "/app/public/images"
          }
        }

        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        volume {
          name = "config-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.homepage_config.metadata[0].name
          }
        }

        volume {
          name = "config-images"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.homepage_images.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "homepage" {
  metadata {
    name      = "homepage"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }

  spec {
    selector = {
      app = "homepage"
    }

    port {
      port        = 80
      target_port = 3000
      name        = "http"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "homepage" {
  metadata {
    name      = "homepage-ingress"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "homepage.lan"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.homepage.metadata[0].name
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
