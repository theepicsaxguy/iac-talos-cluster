resource "kubernetes_namespace" "argocd" {
  provider   = kubernetes.argocd
  depends_on = [talos_machine_bootstrap.this, null_resource.wait_for_kubernetes]

  metadata {
    name = "argocd"
  }
}

# Wait for the Kubernetes API to be fully ready
resource "null_resource" "wait_for_kubernetes" {
  depends_on = [
    talos_machine_bootstrap.this,
    data.external.copy_kubeconfig,
    talos_cluster_kubeconfig.this
  ]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG  = "${path.module}/output/kubeconfig"
      TALOSCONFIG = "${path.module}/output/talosconfig"
    }
    command = <<-EOT
      max_retries=60
      count=0
      
      # First ensure Talos API is ready
      until talosctl --talosconfig=$TALOSCONFIG --nodes ${local.kubernetes_base_endpoint} version; do
        echo "Waiting for Talos API... (attempt $count/$max_retries)"
        count=$((count + 1))
        if [ $count -ge $max_retries ]; then
          echo "Timeout waiting for Talos API"
          exit 1
        fi
        sleep 5
      done
      
      # Reset counter for Kubernetes API check
      count=0
      
      # Then wait for Kubernetes API
      until kubectl --kubeconfig=$KUBECONFIG cluster-info; do
        echo "Waiting for Kubernetes API... (attempt $count/$max_retries)"
        count=$((count + 1))
        if [ $count -ge $max_retries ]; then
          echo "Timeout waiting for Kubernetes API"
          exit 1
        fi
        sleep 5
      done
      
      echo "Waiting for essential Kubernetes components..."
      kubectl --kubeconfig=$KUBECONFIG -n kube-system wait pod --for=condition=Ready --all --timeout=300s
    EOT
  }
}

resource "kubernetes_namespace" "cilium_system" {
  depends_on = [null_resource.wait_for_kubernetes]

  metadata {
    name = "cilium-system"
    labels = {
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

resource "helm_release" "argocd" {
  provider   = helm.argocd
  depends_on = [kubernetes_namespace.argocd, null_resource.wait_for_kubernetes]

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "configs.cm.kustomize\\.enabled"
    value = "true"
  }

  timeout = 900 # 15 minutes

  wait          = true
  wait_for_jobs = true

  values = [
    file("${path.module}/manifests/argocd/values.yaml")
  ]
}

resource "helm_release" "cilium" {
  provider   = helm.argocd
  depends_on = [kubernetes_namespace.cilium_system, null_resource.wait_for_kubernetes]

  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = kubernetes_namespace.cilium_system.metadata[0].name

  timeout = 900 # 15 minutes

  wait          = true
  wait_for_jobs = true

  values = [
    file("${path.module}/manifests/cilium/base/values.yaml")
  ]
}

# Wait for CRDs to be ready before applying Application resources
resource "time_sleep" "wait_for_crds" {
  depends_on = [helm_release.argocd]

  create_duration = "30s"
}

# Configure ArgoCD Applications
resource "kubernetes_manifest" "argocd_applications" {
  provider   = kubernetes
  depends_on = [time_sleep.wait_for_crds, helm_release.argocd, null_resource.wait_for_kubernetes]
  for_each = {
    for f in fileset(path.module, "manifests/apps/*.yaml") : basename(f) => f
    if !endswith(f, "kustomization.yaml") && fileexists(f)
  }

  manifest = yamldecode(file(each.value))

  timeouts {
    create = "5m"
    update = "5m"
    delete = "5m"
  }

  wait {
    fields = {
      "status.sync.status" = "Synced"
    }
  }
}

resource "kubernetes_manifest" "cilium_bgp_cluster_config" {
  provider   = kubernetes
  depends_on = [helm_release.cilium, null_resource.wait_for_kubernetes]

  manifest = yamldecode(templatefile("${path.module}/manifests/cilium/bgp-cluster-config.yaml.tpl", {
    cilium_asn = var.cilium_asn,
    router_ip  = var.router_ip != "" ? var.router_ip : var.network_gateway,
    router_asn = var.router_asn,
  }))
}

