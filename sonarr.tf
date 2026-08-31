resource "kubernetes_persistent_volume_v1" "sonarr_config" {
  metadata { name = "sonarr-config-pv" }
  spec {
    capacity           = { storage = "5Gi" }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/sonarr/config"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "sonarr_config" {
  metadata {
    name      = "sonarr-config-pvc"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.sonarr_config.metadata[0].name
    resources { requests = { storage = "5Gi" } }
  }
}

resource "kubernetes_persistent_volume_v1" "sonarr_serials" {
  metadata { name = "sonarr-serials-pv" }
  spec {
    capacity           = { storage = "500Gi" }
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/video/serials"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "sonarr_serials" {
  metadata {
    name      = "sonarr-serials-pvc"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.sonarr_serials.metadata[0].name
    resources { requests = { storage = "500Gi" } }
  }
}

resource "kubernetes_deployment_v1" "sonarr" {
  metadata {
    name      = "sonarr"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "sonarr" } }

    template {
      metadata {
        labels = {
          app                      = "sonarr"
          "app.kubernetes.io/name" = "sonarr"
        }
      }

      spec {
        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        container {
          name  = "sonarr"
          image = "lscr.io/linuxserver/sonarr:latest"

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
            container_port = 8989
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
            name  = "SONARR__POSTGRES__HOST"
            value = "postgres.postgres.svc.cluster.local"
          }
          env {
            name  = "SONARR__POSTGRES__PORT"
            value = "5432"
          }
          env {
            name  = "SONARR__POSTGRES__MAINDB"
            value = "sonarr_main"
          }
          env {
            name  = "SONARR__POSTGRES__LOGDB"
            value = "sonarr_log"
          }
          env {
            name  = "SONARR__POSTGRES__USER"
            value = "sonarr"
          }
          env {
            name = "SONARR__POSTGRES__PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.arr_secrets.metadata[0].name
                key  = "SONARR_DB_PASSWORD"
              }
            }
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
            name       = "arr"
            mount_path = "/arr"
          }
        }

        volume {
          name = "config"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.sonarr_config.metadata[0].name
          }
        }

        volume {
          name = "serials"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.sonarr_serials.metadata[0].name
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

resource "kubernetes_service_v1" "sonarr" {
  metadata {
    name      = "sonarr"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    selector = { app = "sonarr" }
    port {
      name        = "http"
      port        = 80
      target_port = 8989
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "sonarr" {
  metadata {
    name      = "sonarr-ingress"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    ingress_class_name = "traefik"
    rule {
      host = "sonarr.lan"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.sonarr.metadata[0].name
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}
