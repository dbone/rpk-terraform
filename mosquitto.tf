resource "kubernetes_namespace" "mosquitto" {
  metadata {
    name = "mosquitto"
  }
}

resource "kubernetes_persistent_volume_v1" "mosquitto_config" {
  metadata {
    name = "mosquitto-config-pv"
  }
  spec {
    capacity           = { storage = "1Gi" }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/mosquitto/config"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "mosquitto_config" {
  metadata {
    name      = "mosquitto-config-pvc"
    namespace = kubernetes_namespace.mosquitto.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.mosquitto_config.metadata[0].name
    resources {
      requests = { storage = "1Gi" }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "mosquitto_data" {
  metadata {
    name = "mosquitto-data-pv"
  }
  spec {
    capacity           = { storage = "5Gi" }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/mosquitto/data"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "mosquitto_data" {
  metadata {
    name      = "mosquitto-data-pvc"
    namespace = kubernetes_namespace.mosquitto.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.mosquitto_data.metadata[0].name
    resources {
      requests = { storage = "5Gi" }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "mosquitto_log" {
  metadata {
    name = "mosquitto-log-pv"
  }
  spec {
    capacity           = { storage = "5Gi" }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    persistent_volume_source {
      host_path {
        path = "/net/hastur/mnt/bunker/persistent/mosquitto/log"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "mosquitto_log" {
  metadata {
    name      = "mosquitto-log-pvc"
    namespace = kubernetes_namespace.mosquitto.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-manual"
    volume_name        = kubernetes_persistent_volume_v1.mosquitto_log.metadata[0].name
    resources {
      requests = { storage = "5Gi" }
    }
  }
}

resource "kubernetes_deployment_v1" "mosquitto" {
  metadata {
    name      = "mosquitto"
    namespace = kubernetes_namespace.mosquitto.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mosquitto"
      }
    }

    template {
      metadata {
        labels = {
          app                      = "mosquitto"
          "app.kubernetes.io/name" = "mosquitto"
        }
      }

      spec {
        container {
          name  = "mosquitto"
          image = "eclipse-mosquitto:latest"

          port {
            name           = "mqtt"
            container_port = 1883
          }

          volume_mount {
            name       = "mosquitto-config"
            mount_path = "/mosquitto/config"
          }

          volume_mount {
            name       = "mosquitto-data"
            mount_path = "/mosquitto/data"
          }

          volume_mount {
            name       = "mosquitto-log"
            mount_path = "/mosquitto/log"
          }
        }

        node_selector = {
          "node-role.kubernetes.io/worker" = "worker"
        }

        volume {
          name = "mosquitto-config"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.mosquitto_config.metadata[0].name
          }
        }

        volume {
          name = "mosquitto-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.mosquitto_data.metadata[0].name
          }
        }

        volume {
          name = "mosquitto-log"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.mosquitto_log.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "mosquitto" {
  metadata {
    name      = "mosquitto"
    namespace = kubernetes_namespace.mosquitto.metadata[0].name
  }

  spec {
    selector = {
      app = "mosquitto"
    }

    port {
      name        = "mqtt"
      port        = 1883
      target_port = 1883
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
