variable "talos_iso_download_url" {
  description = "Location to download the Talos iso image from"
  type        = string
  # % is replaced by talos_version
  default     = "https://github.com/siderolabs/talos/releases/download/v%/metal-amd64.iso"
}

variable "talos_iso_destination_filename" {
  description = "Filename of the Talos iso image to store"
  type        = string
  # % is replaced by talos_version
  default     = "talos-%-metal-amd64.iso"
}

variable "talos_iso_destination_server" {
  description = "Proxmox server to store the Talos iso image on"
  type        = string
  default     = ""
}

variable "talos_iso_destination_storage_pool" {
  description = "Proxmox storage to store the Talos iso image on"
  type        = string
  default     = "local"
}
variable "talos_iso_path" {
  description = "The path to the Talos ISO file in the Proxmox storage"
  type        = string
  default     = "metal-amd64.iso"
}
