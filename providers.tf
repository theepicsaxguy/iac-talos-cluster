terraform {
  required_version = ">= 1.0"
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = ">= 0.7.2"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.2.2"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.1"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    proxmox = {
      # https://registry.terraform.io/providers/bpg/proxmox/latest/docs
      source  = "bpg/proxmox"
      version = ">= 0.70.1"
    }
    talos = {
      # https://registry.terraform.io/providers/siderolabs/talos/latest/docs
      source  = "siderolabs/talos"
      version = ">= 0.7.0"
    }
    synclocal = {
      source  = "justenwalker/synclocal"
      version = ">= 0.0.2"
    }
    macaddress = {
      source  = "ivoronin/macaddress"
      version = "0.3.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}
# Kubectl Provider Configuration
provider "kubectl" {
  config_path = "~/.kube/config" # Ensure correct kubeconfig path
}

provider "kubernetes" {
  config_path = "~/.kube/config" # or the path to your kubeconfig
}

provider "kubernetes" {
  alias       = "argocd"
  config_path = "~/.kube/config"
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = true
}
