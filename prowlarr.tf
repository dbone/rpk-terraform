resource "kubernetes_persistent_volume_v1" "prowlarr_config" {
  metadata { name = "prowlarr-config-pv" }
  spec {
    capacity           = { storage = "5Gi" }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/prowlarr/config"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "prowlarr_config" {
  metadata {
    name      = "prowlarr-config-pvc"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.prowlarr_config.metadata[0].name
    resources { requests = { storage = "5Gi" } }
  }
}

resource "kubernetes_deployment_v1" "prowlarr" {
  metadata {
    name      = "prowlarr"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "prowlarr" } }

    template {
      metadata {
        labels = {
          app                      = "prowlarr"
          "app.kubernetes.io/name" = "prowlarr"
        }
      }

      spec {
        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        container {
          name  = "prowlarr"
          image = "lscr.io/linuxserver/prowlarr:latest"

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
            container_port = 9696
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
        }

        volume {
          name = "config"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.prowlarr_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "prowlarr" {
  metadata {
    name      = "prowlarr"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    selector = { app = "prowlarr" }
    port {
      name        = "http"
      port        = 80
      target_port = 9696
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "prowlarr" {
  metadata {
    name      = "prowlarr-ingress"
    namespace = kubernetes_namespace.arr_stack.metadata[0].name
  }
  spec {
    ingress_class_name = "traefik"
    rule {
      host = "prowlarr.lan"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.prowlarr.metadata[0].name
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}
