resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = data.talos_client_configuration.this.client_configuration
  node                 = local.kubernetes_base_endpoint
}

resource "local_sensitive_file" "export_talosconfig" {
  depends_on = [data.talos_client_configuration.this]
  content    = data.talos_client_configuration.this.talos_config
  filename   = "${path.module}/output/talosconfig"
}

resource "local_sensitive_file" "export_kubeconfig" {
  depends_on = [talos_cluster_kubeconfig.this]
  content    = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename   = "${path.module}/output/kubeconfig"
}

data "external" "copy_talosconfig" {
  depends_on = [local_sensitive_file.export_talosconfig]

  program = [
    "go",
    "run",
    "${path.module}/cmd/cp-to-home",
    "${path.module}/output/talosconfig",
    "~/.talos/config",
  ]
}

data "external" "copy_kubeconfig" {
  depends_on = [local_sensitive_file.export_kubeconfig]

  program = [
    "go",
    "run",
    "${path.module}/cmd/cp-to-home",
    "${path.module}/output/kubeconfig",
    "~/.kube/config",
  ]
}

resource "null_resource" "talos-cluster-up" {
  depends_on = [
    data.external.copy_talosconfig,
    data.external.copy_kubeconfig,
    talos_machine_bootstrap.this
  ]

  # This ensures we wait for both API server health and basic node readiness
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for Kubernetes API to be healthy
      for i in {1..30}; do
        if curl -k --fail --max-time 5 ${local.kubernetes_endpoint}/healthz; then
          break
        fi
        if [ $i -eq 30 ]; then
          echo "Timed out waiting for Kubernetes API" >&2
          exit 1
        fi
        echo "Waiting for Kubernetes API to be ready..."
        sleep 10
      done

      # Wait for nodes to be ready
      for i in {1..30}; do
        if go run ${path.module}/cmd/nodes-ready/main.go; then
          exit 0
        fi
        if [ $i -eq 30 ]; then  # Fixed missing space before ]
          echo "Timed out waiting for nodes to be ready" >&2
          exit 1
        fi
        echo "Waiting for nodes to be ready..."
        sleep 10
      done
    EOT
  }
}

output "talos_client_configuration" {
  value     = data.talos_client_configuration.this
  sensitive = true
}

output "talos_cluster_kubeconfig" {
  value     = talos_cluster_kubeconfig.this
  sensitive = true
}
