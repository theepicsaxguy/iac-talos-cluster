variable "proxmox_api_token_id" {
  description = "The ID of the API token used for authentication with the Proxmox API."
  type        = string
}

variable "proxmox_api_token_secret" {
  description = "The secret value of the token used for authentication with the Proxmox API."
  type        = string
}

variable "proxmox_api_url" {
  description = "The URL for the Proxmox API."
  type        = string
}

variable "proxmox_storage_type" {
  description = "Storage type for Proxmox VMs (e.g., 'zfspool' for ZFS)."
  type        = string
  default     = "zfspool"
}

variable "proxmox_vlan_tag" {
  description = "Optional VLAN tag for Proxmox VMs."
  type        = number
  default     = 0
}

variable "proxmox_api_insecure" {
  description = "Allow insecure HTTPS connections (use with caution)."
  type        = bool
  default     = false
}

variable "proxmox_servers" {
  description = "Proxmox servers on which the talos cluster will be deployed"
  type        = map(object({
    control_planes_count = optional(number, 1)
    disk_storage_pool    = string
    network_bridge       = optional(string, "vmbr0")
    node_labels          = optional(map(string), {})
  }))
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  insecure  = var.proxmox_api_insecure
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
}
