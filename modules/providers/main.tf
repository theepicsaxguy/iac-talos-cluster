variable "kubernetes_endpoint" {}
variable "client_certificate" {}
variable "client_key" {}
variable "cluster_ca_certificate" {}


provider "helm" {
  kubernetes {
    host = var.kubernetes_endpoint

    client_certificate     = var.client_certificate
    client_key             = var.client_key
    cluster_ca_certificate = var.cluster_ca_certificate
  }
}
