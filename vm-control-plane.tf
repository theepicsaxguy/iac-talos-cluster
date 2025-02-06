locals {
  talos_iso_image_location = var.talos_iso_path

  vm_control_planes = flatten([
    for name, host in var.proxmox_servers : [
      for i in range(host.control_planes_count) : name
    ]
  ])
  vm_control_planes_count = length(local.vm_control_planes)
}

resource "macaddress" "talos-control-plane" {
  count = length(local.vm_control_planes)
}

resource "proxmox_virtual_environment_vm" "talos-control-plane" {
  depends_on = [
    macaddress.talos-control-plane
  ]
  for_each = {
    for i, x in local.vm_control_planes : i => x
  }

  name          = "${var.control_plane_name_prefix}-${each.key + 1}"
  vm_id         = each.key + var.control_plane_first_id
  node_name     = each.value
  on_boot       = true
  scsi_hardware = "virtio-scsi-pci"

  agent {
    enabled = true
  }

  initialization {
    datastore_id = var.proxmox_servers[each.value].disk_storage_pool
    ip_config {
      ipv4 {
        address = "${cidrhost(var.network_cidr, each.key + var.control_plane_first_ip)}/${split("/", var.network_cidr)[1]}"
        gateway = var.network_gateway
      }
    }
  }

  cdrom {
    enabled = true
    file_id = "local:iso/${var.talos_iso_path}"
  }

  cpu {
    type    = "host"
    sockets = 1
    cores   = var.control_plane_cpu_cores
  }

  memory {
    dedicated = var.control_plane_memory*1024
  }

  network_device {
    enabled     = true
    model       = "virtio"
    bridge      = var.proxmox_servers[each.value].network_bridge
    vlan_tag    = var.proxmox_vlan_tag  # Add VLAN Tag
    mac_address = macaddress.talos-control-plane[each.key].address
    firewall    = false
    vlan_id     = var.proxmox_vlan_tag  // Set VLAN ID here
  }


  operating_system {
    type = "l26" # Linux kernel type
  }

  disk {
    interface    = "virtio0"
    size         = var.control_plane_disk_size
    datastore_id = var.proxmox_servers[each.value].disk_storage_pool
    file_format  = "raw"
    cache        = "writethrough"
    iothread     = true
    backup       = false
  }
}

output "talos_control_plane_mac_addrs" {
  value = macaddress.talos-control-plane
}
