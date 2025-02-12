
# Create Namespaces
resource "kubernetes_namespace" "argocd" {
  provider = kubernetes.argocd
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  provider   = helm.argocd
  depends_on = [kubernetes_namespace.argocd]

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  timeout       = 900
  wait          = true
  wait_for_jobs = true

  values = [
    file("${path.module}/manifests/argocd/values.yaml")
  ]
}

# Deploy Cilium using Helm
resource "helm_release" "cilium" {
  provider = helm.argocd

  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_version

  timeout       = 900
  wait          = true
  wait_for_jobs = true

  values = [
    file("${path.module}/manifests/cilium/base/values.yaml")
  ]
}

# Apply ArgoCD Applications
resource "kubectl_manifest" "argocd_applications" {
  provider   = kubectl.argocd
  depends_on = [helm_release.argocd]

  for_each = {
    for f in fileset(path.module, "manifests/apps/*.yaml") : basename(f) => f
    if !endswith(f, "kustomization.yaml") && fileexists(f)
  }

  yaml_body = file(each.value)
}

# Apply Cilium BGP Cluster Configuration
resource "kubectl_manifest" "cilium_bgp_cluster_config" {
  provider   = kubectl.argocd
  depends_on = [helm_release.cilium]

  yaml_body = templatefile("${path.module}/manifests/cilium/bgp-cluster-config.yaml.tpl", {
    cilium_asn = var.cilium_asn,
    router_ip  = var.router_ip != "" ? var.router_ip : var.network_gateway,
    router_asn = var.router_asn,
  })
}
