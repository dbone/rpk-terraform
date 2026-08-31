resource "kubernetes_persistent_volume_v1" "bazarr_config" {
  metadata { name = "bazarr-config-pv" }
  spec {
    capacity           = { storage = "5Gi" }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/bazarr/config"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "bazarr_config" {
  metadata {
    name      = "bazarr-config-pvc"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.bazarr_config.metadata[0].name
    resources { requests = { storage = "5Gi" } }
  }
}

resource "kubernetes_deployment_v1" "bazarr" {
  metadata {
    name      = "bazarr"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "bazarr" } }

    template {
      metadata {
        labels = {
          app                      = "bazarr"
          "app.kubernetes.io/name" = "bazarr"
        }
      }

      spec {
        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        container {
          name  = "bazarr"
          image = "lscr.io/linuxserver/bazarr:latest"

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
            container_port = 6767
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
            name  = "TZ"
            value = "America/New_York"
          }

          volume_mount {
            name       = "config"
            mount_path = "/config"
          }
          volume_mount {
            name       = "serials"
            mount_path = "/serials"
          }
          volume_mount {
            name       = "movies"
            mount_path = "/movies"
          }
        }

        volume {
          name = "config"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.bazarr_config.metadata[0].name
          }
        }

        volume {
          name = "serials"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.sonarr_serials.metadata[0].name
          }
        }

        volume {
          name = "movies"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.radarr_movies.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "bazarr" {
  metadata {
    name      = "bazarr"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    selector = { app = "bazarr" }
    port {
      name        = "http"
      port        = 80
      target_port = 6767
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "bazarr" {
  metadata {
    name      = "bazarr-ingress"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    ingress_class_name = "traefik"
    rule {
      host = "bazarr.lan"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.bazarr.metadata[0].name
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}
