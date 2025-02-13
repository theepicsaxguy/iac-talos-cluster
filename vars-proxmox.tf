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

variable "proxmox_servers" {
  description = "Proxmox servers on which the talos cluster will be deployed"
  type = map(object({
    control_planes_count = optional(number, 3)
    disk_storage_pool    = string
    network_bridge       = optional(string, "vmbr0")
    vlan_tag             = optional(number, 150)
    node_labels          = optional(map(string), {})
  }))
}
