locals {
  control_plane_public_ipv4_list = [
    for i in range(var.proxmox_servers["host3"].control_planes_count) :
    cidrhost(var.network_cidr, var.control_plane_first_ip + i)
  ]
}
