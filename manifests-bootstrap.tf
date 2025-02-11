# download and kustomize metrics server manifests
resource "synclocal_url" "metrics_server_manifest" {
  url      = local.metrics_server_manifest_url
  filename = "${path.module}/manifests/metrics-server/metrics-server.yaml"
}

# download and kustomize argocd manifests
resource "synclocal_url" "argocd_manifest" {
  url      = local.argocd_manifest_url
  filename = "${path.module}/manifests/argocd/argocd.yaml"
}

# The rest of this file is replaced by kubernetes-native.tf
# Remove all the manual local-exec provisioners and null_resources
