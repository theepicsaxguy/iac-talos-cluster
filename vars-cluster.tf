variable "cluster_name" {
  description = "Name of the Talos Kubernetes cluster"
  type        = string
  default     = "kube"
}

variable "cluster_vip" {
  description = "Virtual IP of the Talos Kubernetes cluster"
  type        = string
}

variable "cluster_domain" {
  description = "Domain name of the Talos Kubernetes cluster"
  type        = string
  default     = "api.kube.pc-tips.se"
}

variable "cluster_endpoint_port" {
  description = "Port of the Kubernetes API endpoint"
  type        = number
  default     = 6443
}

variable "control_plane_first_ip" {
  description = "First ip of a control-plane"
  type        = number
  default     = 11
}

variable "worker_node_first_ip" {
  description = "First ip of a worker node"
  type        = number
  default     = 21
}

variable "install_disk_device" {
  description = "Disk to install Talos on"
  type        = string
  default     = "/dev/vda"
}

variable "ha_mode" {
  description = "Enable High Availability mode"
  type        = bool
  default     = false
}
