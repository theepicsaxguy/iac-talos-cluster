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

# Install ArgoCD first
resource "null_resource" "install_argocd" {
  depends_on = [synclocal_url.argocd_manifest]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
      kubectl apply -n argocd --server-side=true -f ${path.module}/manifests/argocd/argocd.yaml
      # Update ArgoCD and Hubble UI services to LoadBalancer type
      kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
      kubectl patch svc hubble-ui -n cilium-system -p '{"spec": {"type": "LoadBalancer"}}' --force-conflicts=true
    EOT
  }
}

# Wait for ArgoCD CRDs and components to be available
resource "null_resource" "wait_for_argocd_crds" {
  depends_on = [null_resource.install_argocd]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=300s
      kubectl -n argocd wait deployment/argocd-server --for=condition=Available=True --timeout=300s
      kubectl -n argocd wait deployment/argocd-repo-server --for=condition=Available=True --timeout=300s
      kubectl -n argocd wait deployment/argocd-application-controller --for=condition=Available=True --timeout=300s
    EOT
  }
}

# prepare the bootstrap manifests and write them in the output directory
data "external" "kustomize_bootstrap_manifests" {
  depends_on = [
    data.external.talos-nodes-ready,
    synclocal_url.argocd_manifest,
  ]
  for_each = {
    for i, m in var.bootstrap_manifests : "bootstrap-manifest-${i}" => m
  }

  program = [
    "go",
    "run",
    "${path.module}/cmd/kustomize",
    "--",
    "--enable-helm",
    "-o",
    "${path.module}/output/${each.key}.yaml",
    "${path.module}/${each.value}",
  ]
}

# Apply the Argo CD Application Resources
resource "null_resource" "apply_bootstrap_manifests" {
  depends_on = [
    data.external.kustomize_bootstrap_manifests,
    null_resource.wait_for_argocd_crds,
    null_resource.install_argocd
  ]
  for_each = data.external.kustomize_bootstrap_manifests

  provisioner "local-exec" {
    command = <<-EOT
      # Ensure namespaces exist before applying manifests
      kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
      kubectl create namespace cilium-system --dry-run=client -o yaml | kubectl apply -f -
      kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
      # Wait for ArgoCD to be fully ready
      kubectl -n argocd wait --for=condition=Available=True deployment/argocd-server deployment/argocd-repo-server deployment/argocd-application-controller --timeout=300s
      kubectl apply --server-side=true -f ${path.module}/output/${each.key}.yaml
    EOT
  }
}
