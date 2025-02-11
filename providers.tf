variable "init_type" {
  type        = string
  description = "Initialization type: 'all' for full initialization, otherwise partial"
  default     = "all"
}

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

module "kubernetes_providers" {
  source = "./modules/providers"

  kubernetes_endpoint    = local.kubernetes_endpoint
  client_certificate     = base64decode(talos_machine_secrets.this.client_configuration.client_certificate)
  client_key             = base64decode(talos_machine_secrets.this.client_configuration.client_key)
  cluster_ca_certificate = base64decode(talos_machine_secrets.this.client_configuration.ca_certificate)
}
