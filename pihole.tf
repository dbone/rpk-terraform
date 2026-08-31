resource "kubernetes_namespace" "pihole" {
  metadata {
    name = "pihole"
  }
}

resource "kubernetes_secret_v1" "pihole_secret" {
  metadata {
    name      = "pihole-secret"
    namespace = kubernetes_namespace.pihole.metadata[0].name
  }

  data = {
    FTLCONF_webserver_api_password = var.FTLCONF_webserver_api_password
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_v1" "pihole_etc" {
  metadata {
    name = "pihole-etc-pv"
  }

  spec {
    capacity = {
      storage = "5Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"

    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/pihole/etc-pihole"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "pihole_dnsmasq" {
  metadata {
    name = "pihole-dnsmasq-pv"
  }

  spec {
    capacity = {
      storage = "2Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"

    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/pihole/etc-dnsmasq"
        type = "DirectoryOrCreate"
      }
    }
  }
}

# 4. Persistent Volume Claims
resource "kubernetes_persistent_volume_claim_v1" "pihole_etc" {
  metadata {
    name      = "pihole-etc-pvc"
    namespace = kubernetes_namespace.pihole.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.pihole_etc.metadata[0].name

    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "pihole_dnsmasq" {
  metadata {
    name      = "pihole-dnsmasq-pvc"
    namespace = kubernetes_namespace.pihole.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.pihole_dnsmasq.metadata[0].name

    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }
}

# 5. Pi-hole Deployment
resource "kubernetes_deployment_v1" "pihole" {
  metadata {
    name      = "pihole"
    namespace = kubernetes_namespace.pihole.metadata[0].name
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        app = "pihole"
      }
    }

    template {
      metadata {
        labels = {
          app                      = "pihole"
          "app.kubernetes.io/name" = "pihole"
        }
      }

      spec {
        container {
          name  = "pihole"
          image = "pihole/pihole:latest"

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
            name           = "dns-udp"
            container_port = 53
            protocol       = "UDP"
          }

          port {
            name           = "dns-tcp"
            container_port = 53
            protocol       = "TCP"
          }

          port {
            name           = "http"
            container_port = 80
          }

          env {
            name  = "TZ"
            value = "America/New_York"
          }

          env {
            name  = "FTLCONF_dns_upstreams"
            value = "192.168.1.1"
          }

          env {
            name  = "FTLCONF_dns_listeningMode"
            value = "all"
          }

          volume_mount {
            name       = "pihole-etc"
            mount_path = "/etc/pihole"
          }

          volume_mount {
            name       = "pihole-dnsmasq"
            mount_path = "/etc/dnsmasq.d"
          }
        }

        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        volume {
          name = "pihole-etc"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.pihole_etc.metadata[0].name
          }
        }

        volume {
          name = "pihole-dnsmasq"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.pihole_dnsmasq.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "pihole_dns" {
  metadata {
    name      = "pihole-dns"
    namespace = kubernetes_namespace.pihole.metadata[0].name
  }

  spec {
    selector = {
      app = "pihole"
    }

    port {
      name        = "dns-udp"
      port        = 53
      target_port = 53
      protocol    = "UDP"
    }

    port {
      name        = "dns-tcp"
      port        = 53
      target_port = 53
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_service_v1" "pihole_web" {
  metadata {
    name      = "pihole-web"
    namespace = kubernetes_namespace.pihole.metadata[0].name
  }

  spec {
    selector = {
      app = "pihole"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "pihole" {
  metadata {
    name      = "pihole-ingress"
    namespace = kubernetes_namespace.pihole.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "pihole.lan"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.pihole_web.metadata[0].name
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
