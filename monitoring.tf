resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  set {
    name  = "grafana.enabled"
    value = "true"
  }

  set {
    name  = "nodeExporter.serviceMonitor.relabelings[0].sourceLabels[0]"
    value = "__meta_kubernetes_pod_node_name"
  }
  set {
    name  = "nodeExporter.serviceMonitor.relabelings[0].targetLabel"
    value = "node"
  }
  set {
    name  = "nodeExporter.serviceMonitor.relabelings[0].action"
    value = "replace"
  }
}

resource "kubernetes_ingress_v1" "grafana" {
  metadata {
    name      = "grafana-ingress"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "grafana.lan"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "kube-prometheus-stack-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.prometheus_stack]
}
