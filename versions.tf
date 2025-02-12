terraform {
  required_version = ">= 1.0"
  required_providers {
    kustomization = {
      source  = "kbst/kustomization"
      version = "0.9.6"
    }
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
