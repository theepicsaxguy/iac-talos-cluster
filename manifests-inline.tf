locals {
  talos_ccm_manifest_url      = replace(var.talos_ccm_manifest_url, "%", var.talos_ccm_version)
  metrics_server_manifest_url = replace(var.metrics_server_manifest_url, "%", var.metrics_server_version)
  argocd_manifest_url         = replace(var.argocd_manifest_url, "%", var.argocd_version)
}

# download and kustomize talos ccm manifests
resource "synclocal_url" "talos_ccm_manifest" {
  url      = local.talos_ccm_manifest_url
  filename = "${path.module}/manifests/talos-ccm/talos-ccm.yaml"
}

data "kustomization_build" "talos_ccm" {
  depends_on = [synclocal_url.talos_ccm_manifest]
  path       = "${path.module}/manifests/talos-ccm"
}

# kustomize cilium manifests
resource "local_file" "cilium_kustomization" {
  content = templatefile("${path.module}/manifests/cilium/base/kustomization.yaml.tpl", {
    cilium_version = var.cilium_version
  })
  filename = "${path.module}/manifests/cilium/base/kustomization.yaml"
}

data "kustomization_build" "cilium" {
  depends_on = [local_file.cilium_kustomization]
  path       = "${path.module}/manifests/cilium"
  kustomize_options {
    enable_helm = true
    helm_path   = "helm" # Assuming helm is available in PATH, adjust if needed
  }
}

resource "terraform_data" "inline-manifests" {
  depends_on = [
    data.kustomization_build.talos_ccm,
    data.kustomization_build.cilium
  ]

  input = [
    {
      name     = "talos-ccm"
      contents = data.kustomization_build.talos_ccm.manifests
    },
    {
      name     = "cilium"
      contents = data.kustomization_build.cilium.manifests
    }
  ]
}

resource "local_file" "export_inline_manifests" {
  depends_on = [terraform_data.inline-manifests]
  content    = yamlencode(terraform_data.inline-manifests.output)
  filename   = "${path.module}/output/inline-manifests.yaml"
}
