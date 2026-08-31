# 1. Dedicated Namespace
resource "kubernetes_namespace" "forgejo" {
  metadata {
    name = "forgejo"
  }
}

resource "kubernetes_secret_v1" "forgejo_secret" {
  metadata {
    name      = "forgejo-secret"
    namespace = kubernetes_namespace.forgejo.metadata[0].name
  }

  data = {
    FORGEJO_DB_PASSWD = var.FORGEJO_DB_PASSWD
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_v1" "forgejo_data" {
  metadata {
    name = "forgejo-data-pv"
  }

  spec {
    capacity = {
      storage = "20Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"

    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/forgejo/data"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "forgejo_data" {
  metadata {
    name      = "forgejo-data-pvc"
    namespace = kubernetes_namespace.forgejo.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.forgejo_data.metadata[0].name

    resources {
      requests = {
        storage = "20Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "forgejo" {
  metadata {
    name      = "forgejo"
    namespace = kubernetes_namespace.forgejo.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "forgejo"
      }
    }

    template {
      metadata {
        labels = {
          app                      = "forgejo"
          "app.kubernetes.io/name" = "forgejo"
        }
      }

      spec {
        container {
          name  = "forgejo"
          image = "codeberg.org/forgejo/forgejo:10"

          port {
            name           = "http"
            container_port = 3000
          }

          port {
            name           = "ssh"
            container_port = 22
          }

          env {
            name  = "USER_UID"
            value = "1000"
          }

          env {
            name  = "USER_GID"
            value = "1000"
          }

          env {
            name  = "FORGEJO__database__DB_TYPE"
            value = "postgres"
          }

          env {
            name  = "FORGEJO__database__HOST"
            value = "postgres.postgres.svc.cluster.local:5432"
          }

          env {
            name  = "FORGEJO__database__NAME"
            value = "forgejo"
          }

          env {
            name  = "FORGEJO__database__USER"
            value = "forgejo"
          }

          env {
            name = "FORGEJO__database__PASSWD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.forgejo_secret.metadata[0].name
                key  = "FORGEJO_DB_PASSWD"
              }
            }
          }

          env {
            name  = "FORGEJO__server__DOMAIN"
            value = "forgejo.lan"
          }

          env {
            name  = "FORGEJO__server__ROOT_URL"
            value = "http://forgejo.lan/"
          }

          env {
            name  = "FORGEJO__server__SSH_PORT"
            value = "2222"
          }

          env {
            name  = "FORGEJO__server__SSH_LISTEN_PORT"
            value = "22"
          }

          volume_mount {
            name       = "forgejo-data"
            mount_path = "/data"
          }
        }

        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        volume {
          name = "forgejo-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.forgejo_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "forgejo_http" {
  metadata {
    name      = "forgejo-http"
    namespace = kubernetes_namespace.forgejo.metadata[0].name
  }

  spec {
    selector = {
      app = "forgejo"
    }

    port {
      name        = "http"
      port        = 3000
      target_port = 3000
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_service_v1" "forgejo_ssh" {
  metadata {
    name      = "forgejo-ssh"
    namespace = kubernetes_namespace.forgejo.metadata[0].name
  }

  spec {
    selector = {
      app = "forgejo"
    }

    port {
      name        = "ssh"
      port        = 2222
      target_port = 22
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_ingress_v1" "forgejo" {
  metadata {
    name      = "forgejo-ingress"
    namespace = kubernetes_namespace.forgejo.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "forgejo.lan"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.forgejo_http.metadata[0].name
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }
}
