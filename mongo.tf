# mongodb service
resource "kubernetes_service" "mongo_service" {
  metadata {
    name = "mongo"
    namespace = kubernetes_namespace.graylog.metadata[0].name
  }
  spec {
    selector = {
      app = "mongo"
    }
    port {
      name = "mongodb-transport"
      port = 27017
      target_port = 27017
      protocol = "TCP"
    }
    port {
      name= "mongodb-shardsvr"
      port = 27018
      target_port = 27018
      protocol = "TCP"
    }
    port {
      name = "mongodb-configsvr"
      port = 27019
      target_port = 27019
      protocol = "TCP"
    }
  }
}

# use host dir for persistent volume
resource "kubernetes_persistent_volume" "mongodb_vol" {
  metadata { name = "graylog-mongodb-vol" }
  spec {
    access_modes = ["ReadWriteOnce"]
    capacity = {
      storage = "100Mi"
    }
    persistent_volume_source {
      host_path {
        path = "/mnt/graylog-mongodb"
      }
    }
    storage_class_name = var.storage_class_name
  }
}

# create pvc
resource "kubernetes_persistent_volume_claim" "mongodb_pvc" {
  metadata {
    name = "mongodb-pvc"
    namespace = kubernetes_namespace.graylog.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "100Mi"
      }
    }
    volume_name = kubernetes_persistent_volume.mongodb_vol.metadata[0].name
    storage_class_name = var.storage_class_name
  }
}

# mongodb stateful set
resource "kubernetes_stateful_set" "mongo_statefulset" {
  metadata {
    name = "mongo"
    namespace = kubernetes_namespace.graylog.metadata[0].name
    labels = { app = "mongo" }
  }
  spec {
    replicas = 1
    update_strategy {
      type = "RollingUpdate"
      rolling_update {
        partition = 0
      }
    }

    selector {
      match_labels = { app = "mongo" }
    }
    service_name = kubernetes_service.mongo_service.metadata[0].name
    template {
      metadata {
        labels = {
          app = "mongo"
        }
      }
      spec {

        container {
          name = "mongo"
          image = var.mongo_docker_image
          volume_mount {
            mount_path = "/data/db"
            name = "vol-mongo-data"
          }
          port { container_port = 27017 }
          port { container_port = 27018 }
          port { container_port = 27019 }
        }

        volume {
          name = "vol-mongo-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mongodb_pvc.metadata[0].name
          }
        }
      }
    }
  }
}
