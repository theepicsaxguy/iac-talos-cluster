locals {
  kubernetes_base_endpoint = var.ha_mode ? var.cluster_vip : cidrhost(var.network_cidr, var.control_plane_first_ip)
  kubernetes_endpoint      = "https://${local.kubernetes_base_endpoint}:${var.cluster_endpoint_port}"
  cluster_endpoint         = local.kubernetes_endpoint
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = true
}

provider "kubernetes" {
  alias       = "argocd"
  config_path = fileexists("${path.module}/output/kubeconfig") ? "${path.module}/output/kubeconfig" : null
}

provider "kubectl" {
  alias                  = "argocd"
  host                   = jsondecode(talos_cluster_kubeconfig.this.kubeconfig_raw)["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(talos_machine_secrets.this.client_configuration.ca_certificate)
  client_certificate     = base64decode(talos_machine_secrets.this.client_configuration.client_certificate)
  client_key             = base64decode(talos_machine_secrets.this.client_configuration.client_key)
  load_config_file       = false
}

provider "kustomization" {
  kubeconfig_raw = talos_cluster_kubeconfig.this.kubeconfig_raw
}

provider "helm" {
  alias = "argocd"
  kubernetes {
    host                   = local.kubernetes_endpoint
    client_certificate     = base64decode(talos_machine_secrets.this.client_configuration.client_certificate)
    client_key             = base64decode(talos_machine_secrets.this.client_configuration.client_key)
    cluster_ca_certificate = base64decode(talos_machine_secrets.this.client_configuration.ca_certificate)
  }
}
