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
  alias = "argocd"
  host                   = local.kubeconfig_data.host
  client_certificate     = local.kubeconfig_data.client_certificate
  client_key             = local.kubeconfig_data.client_key
  cluster_ca_certificate = local.kubeconfig_data.cluster_ca_certificate
  load_config_file       = false
}

provider "kubectl" {
  alias = "argocd"
  host                   = local.kubeconfig_data.host
  client_certificate     = local.kubeconfig_data.client_certificate
  client_key             = local.kubeconfig_data.client_key
  cluster_ca_certificate = local.kubeconfig_data.cluster_ca_certificate
  load_config_file       = false
  apply_retry_count      = 3
}

provider "helm" {
  alias = "argocd"
  kubernetes {
    host                   = local.kubeconfig_data.host
    client_certificate     = local.kubeconfig_data.client_certificate
    client_key             = local.kubeconfig_data.client_key
    cluster_ca_certificate = local.kubeconfig_data.cluster_ca_certificate
  }
}

provider "helm" {
  kubernetes {
    host                   = local.kubeconfig_data.host
    client_certificate     = local.kubeconfig_data.client_certificate
    client_key             = local.kubeconfig_data.client_key
    cluster_ca_certificate = local.kubeconfig_data.cluster_ca_certificate
  }
}

provider "kustomization" {
  host                   = local.kubeconfig_data.host
  client_certificate     = local.kubeconfig_data.client_certificate
  client_key             = local.kubeconfig_data.client_key
  cluster_ca_certificate = local.kubeconfig_data.cluster_ca_certificate
}

# This resource ensures all providers have a working cluster before proceeding
resource "null_resource" "providers_dependency" {
  depends_on = [null_resource.talos-cluster-up]

  provisioner "local-exec" {
    command = <<-EOT
      for i in {1..30}; do
        if curl -k --fail --max-time 5 ${local.kubernetes_endpoint}/healthz; then
          exit 0
        fi
        sleep 10
      done
      echo "Timed out waiting for cluster API" >&2
      exit 1
    EOT
  }
}
