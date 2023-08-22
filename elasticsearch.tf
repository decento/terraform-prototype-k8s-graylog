# elasticsearch secrets
resource "kubernetes_config_map" "elasticsearch_config" {
  metadata {
    name = "elasticsearch-env"
    namespace = kubernetes_namespace.graylog.metadata[0].name
  }
  data = {
    "ES_JAVA_OPTS" = "-Dlog4j2.formatMsgNoLookups=true -Xms512m -Xmx512m"
    "http.host" = "0.0.0.0"
    "network.host" = "0.0.0.0"
    "transport.host" = "localhost"
    "discovery.type" = "single-node"
  }
}

# elasticsearch service
resource "kubernetes_service" "elasticsearch_service" {
  metadata {
    name = "elasticsearch"
    namespace = kubernetes_namespace.graylog.metadata[0].name
  }
  spec {
    selector = {
      app = "elasticsearch"
    }
    port {
      name = "elasticsearch-http"
      port = 9200
      target_port = 9200
      protocol = "TCP"
    }
    port {
      name= "elasticsearch-transport"
      port = 9300
      target_port = 9300
      protocol = "TCP"
    }
  }
}

# use host dir for persistent volume
resource "kubernetes_persistent_volume" "elastic_vol" {
  metadata { name = "elastic-vol" }
  spec {
    access_modes = ["ReadWriteOnce"]
    capacity = {
      storage = "1Gi"
    }
    persistent_volume_source {
      host_path {
        path = "/mnt/graylog-elastic"
      }
    }
    storage_class_name = var.storage_class_name
  }
}

# create pvc
resource "kubernetes_persistent_volume_claim" "elastic_pvc" {
  metadata {
    name = "elastic-pvc"
    namespace = kubernetes_namespace.graylog.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    volume_name = kubernetes_persistent_volume.elastic_vol.metadata[0].name
    storage_class_name = var.storage_class_name
  }
}

# elasticsearch stateful set
resource "kubernetes_stateful_set" "elasticsearch_deployment" {
  metadata {
    name = "elasticsearch"
    namespace = kubernetes_namespace.graylog.metadata[0].name
    labels = { app = "elasticsearch" }
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
      match_labels = { app = "elasticsearch" }
    }
    service_name = kubernetes_service.elasticsearch_service.metadata[0].name
    template {
      metadata {
        labels = { app = "elasticsearch" }
      }
      spec {
        container {
          name = "elasticsearch"
          image = var.elasticsearch_docker_image
          volume_mount {
            mount_path = "/usr/share/elasticsearch/data"
            name = "vol-elasticsearch-data"
            sub_path = "data"
          }
          env_from {
            config_map_ref {
              name = kubernetes_config_map.elasticsearch_config.metadata[0].name
            }
          }
          port { container_port = 9200 }
          port { container_port = 9300 }
        }
        init_container {
          name = "elasticsearch-fix-vol-permissions"
          image = "busybox:latest"
          image_pull_policy = "IfNotPresent"
          command = ["sh", "-c", "mkdir -p /elasticsearch/data ; chown -R 1000:1000 /elasticsearch/data"]
          volume_mount {
            mount_path = "/elasticsearch"
            name = "vol-elasticsearch-data"
          }
        }
        volume {
          name = "vol-elasticsearch-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.elastic_pvc.metadata[0].name
          }
        }
      }
    }
  }
}
