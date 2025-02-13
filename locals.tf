locals {
  control_plane_public_ipv4_list = [
    for i in range(var.proxmox_servers["host3"].control_planes_count) :
    cidrhost(var.network_cidr, var.control_plane_first_ip + i)
  ]

  kubeconfig_data = {
    host                   = jsondecode(talos_cluster_kubeconfig.this.kubeconfig_raw)["clusters"][0]["cluster"]["server"]
    client_certificate     = base64decode(talos_machine_secrets.this.client_configuration.client_certificate)
    client_key             = base64decode(talos_machine_secrets.this.client_configuration.client_key)
    cluster_ca_certificate = base64decode(talos_machine_secrets.this.client_configuration.ca_certificate)
  }
}
