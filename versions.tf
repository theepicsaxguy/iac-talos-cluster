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
  # default = "ghcr.io/siderolabs/installer:v%" // = default, when not using system extensions
  # upgrade factory.talos.dev/installer/88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b:
}

variable "k8s_version" {
  # https://www.talos.dev/v1.7/introduction/support-matrix/
  description = "Kubernetes version to use"
  type        = string
  default     = "1.32.0"
}

variable "talos_ccm_version" {
  # https://github.com/siderolabs/talos-cloud-controller-manager/releases
  description = "Talos Cloud Controller Manager version to use"
  type        = string
  default     = "1.9.0"
}

variable "cilium_version" {
  # https://helm.cilium.io/
  description = "Cilium Helm version to use"
  type        = string
  default     = "1.17.0"
}

variable "argocd_version" {
  # https://github.com/argoproj/argo-cd/releases
  description = "ArgoCD version to use"
  type        = string
  default     = "2.14.2"
}

variable "metrics_server_version" {
  # https://github.com/kubernetes-sigs/metrics-server/releases
  description = "Kubernetes Metrics Server version to use"
  type        = string
  default     = "0.7.2"
}
terraform {
  required_version = ">= 1.0"
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.2.3"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.2"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.7.0"
    }
    synclocal = {
      source  = "justenwalker/synclocal"
      version = ">= 0.0.2"
    }
    macaddress = {
      source  = "ivoronin/macaddress"
      version = ">= 0.3.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.13.2"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

# Provider configurations (moved outside)
#provider "helm" {
#  alias   = "argocd"
#}