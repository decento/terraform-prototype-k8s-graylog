locals {
  graylog_hostname = split("//", var.graylog_url)[1]
}

resource "kubernetes_namespace" "graylog" {
  metadata { name = var.namespace_name }
}

# graylog configmap
resource "kubernetes_config_map" "graylog_config" {
  metadata {
    name = "graylog-env"
    namespace = kubernetes_namespace.graylog.metadata[0].name
  }
  data = {
    "GRAYLOG_SERVER_JAVA_OPTS" = "-Xms2048m -Xmx4096m"
    "GRAYLOG_WEB_ENDPOINT_URI" = "https://${local.graylog_hostname}/api"
    "GRAYLOG_HTTP_EXTERNAL_URI" = "https://${local.graylog_hostname}/"
    "GRAYLOG_MONGODB_URI" = "mongodb://mongo/graylog"
    "GRAYLOG_ELASTICSEARCH_HOSTS" = "http://elasticsearch:9200"
    "GRAYLOG_PASSWORD_SECRET" = "somepasswordpeppered"
    "GRAYLOG_ROOT_PASSWORD_SHA2" = sha256(var.graylog_root_password)

  }
}

# graylog service
resource "kubernetes_service" "graylog_service" {
  metadata {
    name = "graylog"
    namespace = kubernetes_namespace.graylog.metadata[0].name
  }
  spec {
    selector = {
      app = "graylog"
    }
    type = "NodePort"
    port {
      name = "syslog-tcp"
      port = 514
      target_port = 514
      node_port = 30514
      protocol = "TCP"
    }
    port {
      name= "syslog-udp"
      port = 514
      target_port = 514
      node_port = 30514
      protocol = "UDP"
    }
    port {
      name = "graylog-webui"
      port = 9000
      target_port = 9000
      protocol = "TCP"
    }
    port {
      name = "gelf-tcp"
      port = 12201
      target_port = 12201
      node_port = 32201
      protocol = "TCP"
    }
    port {
      name= "gelf-http"
      port = 12202
      target_port = 12202
      node_port = 32202
      protocol = "TCP"
    }
    port {
      name = "gelf-udp"
      port = 12201
      target_port = 12201
      node_port = 32201
      protocol = "UDP"
    }
  }
}

# graylog ingress
resource "kubernetes_ingress_v1" "graylog_ingress" {
  metadata {
    name = "graylog-ingress"
    namespace = kubernetes_namespace.graylog.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/configuration-snippet" = "proxy_set_header X-Graylog-Server-URL https://$server_name/;"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        path {
          path = "/"
          backend {
            service {
              name = kubernetes_service.graylog_service.metadata[0].name
              port {
                number = 9000
              }
            }
          }
        }
      }
      host = local.graylog_hostname
    }
    tls {
      hosts = [ local.graylog_hostname ]
    }
  }
}

# graylog stateful set
resource "kubernetes_stateful_set" "graylog_deployment" {
  metadata {
    name = "graylog"
    namespace = kubernetes_namespace.graylog.metadata[0].name
    labels = { app = "graylog" }
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
      match_labels = { app = "graylog" }
    }
    service_name = kubernetes_service.graylog_service.metadata[0].name
    template {
      metadata {
        labels = {
          app = "graylog"
        }
      }
      spec {
        container {
          name = "graylog"
          image = var.graylog_docker_image
          env_from {
            config_map_ref {
              name = kubernetes_config_map.graylog_config.metadata[0].name
            }
          }
          port { container_port = 514 }
          port { container_port = 9000 }
          port { container_port = 12201 }
          port { container_port = 12202 }
          port {
            container_port = 514
            protocol = "UDP"
          }
          port {
            container_port = 12201
            protocol = "UDP"
          }
          port {
            container_port = 2055
            protocol = "UDP"
          }
          liveness_probe {
            http_get {
              path = "/"
              port = 9000
              scheme = "HTTP"
            }
            initial_delay_seconds = 500
            period_seconds = 120
          }
          readiness_probe {
            http_get {
              path = "/"
              port = 9000
              scheme = "HTTP"
            }
            initial_delay_seconds = 60
            period_seconds = 60
          }
        }
      }
    }
  }
}

output "graylog_deployment_resource_version" {
  value = kubernetes_stateful_set.graylog_deployment.metadata[0].resource_version
}
