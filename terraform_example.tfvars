# Proxmox API Configuration
proxmox_api_url          = "https://host3/api2/json"
proxmox_api_token_id     = "root@pam!adw"
proxmox_api_token_secret = "token"


cluster_name           = "talos"
cluster_vip            = "10.25.150.10"
cluster_domain         = "talos.local"
cluster_endpoint_port  = 6443
control_plane_first_ip = 11
worker_node_first_ip   = 21
install_disk_device    = "/dev/vda"

proxmox_servers = {
  host3 = {
    control_planes_count = 1
    disk_storage_pool    = "rpool3"
    network_bridge       = "vmbr0"
    node_labels = {
      role = "control-plane"
    }
  }
  worker_nodes = [
    {
      target_server = "host3"
      node_labels = {
        role = "worker"
      }
      count = 1
    }
  ]
}
