resource "kubernetes_persistent_volume_v1" "sabnzbd_config" {
  metadata { name = "sabnzbd-config-pv" }
  spec {
    capacity           = { storage = "5Gi" }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/sabnzbd/config"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "sabnzbd_config" {
  metadata {
    name      = "sabnzbd-config-pvc"
    namespace = "arr-stack"
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.sabnzbd_config.metadata[0].name
    resources { requests = { storage = "5Gi" } }
  }
}

resource "kubernetes_deployment_v1" "sabnzbd" {
  metadata {
    name      = "sabnzbd"
    namespace = "arr-stack"
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "sabnzbd" } }

    template {
      metadata {
        labels = {
          app                      = "sabnzbd"
          "app.kubernetes.io/name" = "sabnzbd"
        }
      }

      spec {
        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        container {
          name  = "sabnzbd"
          image = "lscr.io/linuxserver/sabnzbd:latest"

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
            container_port = 8080
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
            name       = "sabnzbd-config"
            mount_path = "/config"
          }

          volume_mount {
            name       = "arr"
            mount_path = "/arr"
          }
        }

        volume {
          name = "sabnzbd-config"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.sabnzbd_config.metadata[0].name
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

resource "kubernetes_service_v1" "sabnzbd" {
  metadata {
    name      = "sabnzbd"
    namespace = "arr-stack"
  }
  spec {
    selector = { app = "sabnzbd" }
    port {
      name        = "http"
      port        = 80
      target_port = 8080
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "sabnzbd" {
  metadata {
    name      = "sabnzbd-ingress"
    namespace = "arr-stack"
  }
  spec {
    ingress_class_name = "traefik"
    rule {
      host = "sabnzbd.lan"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.sabnzbd.metadata[0].name
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}
