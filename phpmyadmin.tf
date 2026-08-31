resource "kubernetes_namespace" "phpmyadmin" {
  metadata {
    name = "phpmyadmin"
  }
}

resource "kubernetes_deployment_v1" "phpmyadmin" {
  metadata {
    name      = "phpmyadmin"
    namespace = kubernetes_namespace.phpmyadmin.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "phpmyadmin"
      }
    }

    template {
      metadata {
        labels = {
          app                      = "phpmyadmin"
          "app.kubernetes.io/name" = "phpmyadmin"
        }
      }

      spec {
        container {
          name  = "phpmyadmin"
          image = "phpmyadmin:latest"

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
            name  = "PMA_HOST"
            value = "mariadb.mariadb.svc.cluster.local"
          }

          env {
            name  = "PMA_PORT"
            value = "3306"
          }

          env {
            name  = "UPLOAD_LIMIT"
            value = "128M"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "phpmyadmin" {
  metadata {
    name      = "phpmyadmin"
    namespace = kubernetes_namespace.phpmyadmin.metadata[0].name
  }

  spec {
    selector = {
      app = "phpmyadmin"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "phpmyadmin" {
  metadata {
    name      = "phpmyadmin-ingress"
    namespace = kubernetes_namespace.phpmyadmin.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "phpmyadmin.lan"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.phpmyadmin.metadata[0].name
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
