locals {
  # only keep talos specific defaults here, kubernetes_base_endpoint moved to providers.tf
  talos_mc_defaults = {
    topology_region     = var.cluster_name,
    talos_version       = var.talos_version,
    network_gateway     = var.network_gateway,
    install_disk_device = var.install_disk_device,
    install_image_url   = replace(var.talos_machine_install_image_url, "%", var.talos_version),
  }
}

resource "talos_machine_secrets" "this" {}

data "talos_client_configuration" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  cluster_name         = var.cluster_name
  endpoints = [
    for i in range(var.control_plane_first_ip, var.control_plane_first_ip + local.vm_control_planes_count) : 
    cidrhost(var.network_cidr, i)
  ]
}

data "talos_machine_configuration" "init" {
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kubernetes_endpoint
  talos_version      = "v${var.talos_version}"
  kubernetes_version = "v${var.k8s_version}"
  
  config_patches = [
    templatefile("${path.module}/talos-config/init-boot.yaml.tpl", 
      merge(local.talos_mc_defaults, {
        hostname = "${var.control_plane_name_prefix}-1"
        network_interface = "enx${lower(replace(macaddress.talos-control-plane[0].address, ":", ""))}"
        ipv4_local = cidrhost(var.network_cidr, var.control_plane_first_ip)
        network_ip_prefix = var.network_ip_prefix
      })
    )
  ]
}

data "talos_machine_configuration" "cp" {
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kubernetes_endpoint
  talos_version      = "v${var.talos_version}"
  kubernetes_version = "v${var.k8s_version}"
  docs               = false
  examples           = false

  config_patches = [
    templatefile("${path.module}/talos-config/default.yaml.tpl", local.talos_mc_defaults),
  ]
}

data "talos_machine_configuration" "wn" {
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kubernetes_endpoint
  talos_version      = "v${var.talos_version}"
  kubernetes_version = "v${var.k8s_version}"
  docs               = false
  examples           = false

  config_patches = [
    templatefile("${path.module}/talos-config/default.yaml.tpl", local.talos_mc_defaults),
  ]
}
