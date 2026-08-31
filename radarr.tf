resource "kubernetes_persistent_volume_v1" "radarr_config" {
  metadata { name = "radarr-config-pv" }
  spec {
    capacity           = { storage = "5Gi" }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/radarr/config"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "radarr_config" {
  metadata {
    name      = "radarr-config-pvc"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.radarr_config.metadata[0].name
    resources { requests = { storage = "5Gi" } }
  }
}

resource "kubernetes_persistent_volume_v1" "radarr_movies" {
  metadata { name = "radarr-movies-pv" }
  spec {
    capacity           = { storage = "1Ti" }
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/video/movies"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "radarr_movies" {
  metadata {
    name      = "radarr-movies-pvc"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.radarr_movies.metadata[0].name
    resources { requests = { storage = "1Ti" } }
  }
}

resource "kubernetes_deployment_v1" "radarr" {
  metadata {
    name      = "radarr"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "radarr" } }

    template {
      metadata {
        labels = {
          app                      = "radarr"
          "app.kubernetes.io/name" = "radarr"
        }
      }

      spec {
        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        container {
          name  = "radarr"
          image = "lscr.io/linuxserver/radarr:latest"

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
            container_port = 7878
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
            name  = "RADARR__POSTGRES__HOST"
            value = "postgres.postgres.svc.cluster.local"
          }
          env {
            name  = "RADARR__POSTGRES__PORT"
            value = "5432"
          }
          env {
            name  = "RADARR__POSTGRES__MAINDB"
            value = "radarr_main"
          }
          env {
            name  = "RADARR__POSTGRES__LOGDB"
            value = "radarr_log"
          }
          env {
            name  = "RADARR__POSTGRES__USER"
            value = "radarr"
          }
          env {
            name = "RADARR__POSTGRES__PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.arr_secrets.metadata[0].name
                key  = "RADARR_DB_PASSWORD"
              }
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/config"
          }

          volume_mount {
            name       = "movies"
            mount_path = "/movies"
          }

          volume_mount {
            name       = "arr"
            mount_path = "/arr"
          }
        }

        volume {
          name = "config"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.radarr_config.metadata[0].name
          }
        }

        volume {
          name = "movies"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.radarr_movies.metadata[0].name
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

resource "kubernetes_service_v1" "radarr" {
  metadata {
    name      = "radarr"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    selector = { app = "radarr" }
    port {
      name        = "http"
      port        = 80
      target_port = 7878
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "radarr" {
  metadata {
    name      = "radarr-ingress"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    ingress_class_name = "traefik"
    rule {
      host = "radarr.lan"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.radarr.metadata[0].name
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}
