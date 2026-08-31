resource "kubernetes_persistent_volume_v1" "lidarr_config" {
  metadata { name = "lidarr-config-pv" }
  spec {
    capacity           = { storage = "5Gi" }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/lidarr/config"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "lidarr_config" {
  metadata {
    name      = "lidarr-config-pvc"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.lidarr_config.metadata[0].name
    resources { requests = { storage = "5Gi" } }
  }
}

resource "kubernetes_deployment_v1" "lidarr" {
  metadata {
    name      = "lidarr"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "lidarr" } }

    template {
      metadata {
        labels = {
          app                      = "lidarr"
          "app.kubernetes.io/name" = "lidarr"
        }
      }

      spec {
        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        container {
          name  = "lidarr"
          image = "lscr.io/linuxserver/lidarr:latest"

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
            container_port = 8686
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
          env {
            name  = "LIDARR__POSTGRES__HOST"
            value = "postgres.postgres.svc.cluster.local"
          }
          env {
            name  = "LIDARR__POSTGRES__PORT"
            value = "5432"
          }
          env {
            name  = "LIDARR__POSTGRES__MAINDB"
            value = "lidarr_main"
          }
          env {
            name  = "LIDARR__POSTGRES__LOGDB"
            value = "lidarr_log"
          }
          env {
            name  = "LIDARR__POSTGRES__USER"
            value = "lidarr"
          }
          env {
            name = "LIDARR__POSTGRES__PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.arr_secrets.metadata[0].name
                key  = "LIDARR_DB_PASSWORD"
              }
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/config"
          }
          volume_mount {
            name       = "arr"
            mount_path = "/arr"
          }
        }

        volume {
          name = "config"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.lidarr_config.metadata[0].name
          }
        }
        volume {
          name = "arr"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.arr_interchange.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "lidarr" {
  metadata {
    name      = "lidarr"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    selector = { app = "lidarr" }
    port {
      name        = "http"
      port        = 80
      target_port = 8686
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "lidarr" {
  metadata {
    name      = "lidarr-ingress"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    ingress_class_name = "traefik"
    rule {
      host = "lidarr.lan"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.lidarr.metadata[0].name
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}
