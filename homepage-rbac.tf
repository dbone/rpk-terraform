# ServiceAccount in homepage namespace
resource "kubernetes_service_account_v1" "homepage" {
  metadata {
    name      = "homepage"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }
}

# ClusterRole
resource "kubernetes_cluster_role_v1" "homepage" {
  metadata {
    name = "homepage-reader"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/metrics", "pods", "namespaces", "services"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["nodes", "pods"]
    verbs      = ["get", "list"]
  }
}

# ClusterRoleBinding
resource "kubernetes_cluster_role_binding_v1" "homepage" {
  metadata {
    name = "homepage-reader-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.homepage.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.homepage.metadata[0].name
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }
}
