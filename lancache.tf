resource "kubernetes_namespace" "lancache" {
  metadata {
    name = "lancache"
  }
}

resource "kubernetes_persistent_volume_v1" "lancache_cache" {
  metadata {
    name = "lancache-cache-pv"
  }

  spec {
    capacity = {
      storage = "10000Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"

    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/lancache/data/cache"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "lancache_cache" {
  metadata {
    name      = "lancache-cache-pvc"
    namespace = kubernetes_namespace.lancache.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.lancache_cache.metadata[0].name

    resources {
      requests = {
        storage = "10000Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "lancache" {
  metadata {
    name      = "lancache"
    namespace = kubernetes_namespace.lancache.metadata[0].name
    labels = {
      app = "lancache"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "lancache"
      }
    }

    template {
      metadata {
        labels = {
          app                      = "lancache"
          "app.kubernetes.io/name" = "lancache"
        }
      }

      spec {
        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        container {
          name              = "monolithic"
          image             = "docker.io/library/lancache-monolithic:arm64"
          image_pull_policy = "Never"

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
            container_port = 80
          }

          env {
            name  = "CACHE_MEM_SIZE"
            value = "500m"
          }

          env {
            name  = "CACHE_DISK_SIZE"
            value = "500g"
          }

          env {
            name  = "CACHE_MAX_AGE"
            value = "3650d"
          }

          env {
            name  = "UPSTREAM_DNS"
            value = "192.168.1.1"
          }

          volume_mount {
            name       = "cache-storage"
            mount_path = "/data/cache"
          }
        }

        volume {
          name = "cache-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.lancache_cache.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "lancache" {
  metadata {
    name      = "lancache"
    namespace = kubernetes_namespace.lancache.metadata[0].name
  }

  spec {
    selector = {
      app = "lancache"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  wait_for_load_balancer = false
}

resource "kubernetes_ingress_v1" "lancache" {
  metadata {
    name      = "lancache-ingress"
    namespace = kubernetes_namespace.lancache.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
      "traefik.ingress.kubernetes.io/router.priority"    = "1"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.lancache.metadata[0].name
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
