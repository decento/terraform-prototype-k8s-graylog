variable "namespace_name" { default="graylog" }
variable "storage_class_name" { default = "host-path" }

# graylog vars
variable "graylog_url" { default = "https://graylog.local"}
variable "graylog_root_password" { default = "admin" }
variable "graylog_docker_image" {  default= "graylog/graylog:5.1.4" }

# elasticsearch vars
variable "elasticsearch_docker_image" {  default= "docker.elastic.co/elasticsearch/elasticsearch-oss:7.10.2" }

# mongodb vars
variable "mongo_docker_image" {  default= "mongo:5.0.13" }

# docker desktop Kubernetes API server ~ change as needed
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "docker-desktop"
}
