variable "talos_version" {
  # https://github.com/siderolabs/talos/releases
  description = "Talos version to use"
  type        = string
  default     = "1.9.3"
}

variable "talos_machine_install_image_url" {
  # https://www.talos.dev/v1.7/talos-guides/install/boot-assets/
  description = "The URL of the Talos machine install image"
  type        = string
  # % is replaced by talos_version
  default = "factory.talos.dev/installer/88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b:v%"
}

variable "k8s_version" {
  description = "Kubernetes version to use"
  type        = string
  default     = "1.32.0"
}

variable "talos_ccm_version" {
  description = "Talos Cloud Controller Manager version to use"
  type        = string
  default     = "1.9.0"
}

variable "cilium_version" {
  description = "Cilium Helm version to use"
  type        = string
  default     = "1.17.0"
}

variable "argocd_version" {
  description = "ArgoCD version to use"
  type        = string
  default     = "2.14.2"
}

variable "metrics_server_version" {
  description = "Kubernetes Metrics Server version to use"
  type        = string
  default     = "0.7.2"
}
