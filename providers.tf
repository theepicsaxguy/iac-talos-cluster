terraform {
  required_providers {
    proxmox = {
      # https://registry.terraform.io/providers/bpg/proxmox/latest/docs
      source  = "bpg/proxmox"
      version = ">= 0.70.0"
    }
    talos = {
      # https://registry.terraform.io/providers/siderolabs/talos/latest/docs
      source  = "siderolabs/talos"
      version = ">= 0.5.0"
    }
    synclocal = {
      source  = "justenwalker/synclocal"
      version = ">= 0.0.2"
    }
    macaddress = {
      source  = "ivoronin/macaddress"
      version = "0.3.2"
    }
  }
}

