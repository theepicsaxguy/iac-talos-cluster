resource "terraform_data" "bootstrap_manifests" {
  input = [
    {
      name     = "talos-ccm"
      contents = file("${path.module}/manifests/talos-ccm/talos-ccm.yaml")
    },
    {
      name     = "cilium"
      contents = file("${path.module}/manifests/cilium/base/kustomization.yaml")
    }
  ]
}

resource "talos_machine_configuration_apply" "control-planes" {
  depends_on = [
    data.external.mac-to-ip,
    data.talos_machine_configuration.cp
  ]

  for_each = {
    for i, x in local.vm_control_planes : i => x
  }

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = cidrhost(var.network_cidr, each.key + var.control_plane_first_ip)
  machine_configuration_input = yamlencode({
    machine = {
      type = "controlplane"
      network = {
        hostname = "${var.control_plane_name_prefix}-${each.key + 1}"
        interfaces = [{
          interface = "enx${lower(replace(macaddress.talos-control-plane[each.key].address, ":", ""))}"
          addresses = ["${cidrhost(var.network_cidr, each.key + var.control_plane_first_ip)}/${var.network_ip_prefix}"]
          routes = [{
            network = "0.0.0.0/0"
            gateway = var.network_gateway
          }]
        }]
      }
      kubelet = {
        extraArgs = {
          "node-ip" = cidrhost(var.network_cidr, each.key + var.control_plane_first_ip)
        }
      }
      install = {
        extensions = []
      }
    }
    cluster = {
      apiServer = {
        certSANs = [local.cluster_endpoint]
      }
      controllerManager = {}
      scheduler         = {}
      network = {
        dnsDomain      = var.cluster_domain
        podSubnets     = ["10.244.0.0/16"]
        serviceSubnets = ["10.96.0.0/12"]
      }
      bootstrapManifests = terraform_data.bootstrap_manifests.output
    }
  })
}

resource "time_sleep" "wait_after_control_planes" {
  depends_on      = [talos_machine_configuration_apply.control-planes]
  create_duration = "3m"
}

resource "talos_machine_configuration_apply" "worker-nodes" {
  depends_on = [
    data.external.mac-to-ip,
    data.talos_machine_configuration.wn,
    time_sleep.wait_after_control_planes
  ]

  for_each = {
    for i, x in local.vm_worker_nodes : i => x
  }

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = cidrhost(var.network_cidr, each.key + var.worker_node_first_ip)
  machine_configuration_input = yamlencode({
    machine = {
      type = "worker"
      network = {
        hostname = "${var.worker_node_name_prefix}-${each.key + 1}"
        interfaces = [{
          interface = "enx${lower(replace(macaddress.talos-worker-node[each.key].address, ":", ""))}"
          addresses = ["${cidrhost(var.network_cidr, each.key + var.worker_node_first_ip)}/${var.network_ip_prefix}"]
          routes = [{
            network = "0.0.0.0/0"
            gateway = var.network_gateway
          }]
        }]
      }
      kubelet = {
        extraArgs = {
          "node-ip" = cidrhost(var.network_cidr, each.key + var.worker_node_first_ip)
        }
      }
      install = {
        extensions = []
      }
    }
    cluster = {
      discovery = {
        enabled = true
      }
      network = {
        dnsDomain      = var.cluster_domain
        podSubnets     = ["10.244.0.0/16"]
        serviceSubnets = ["10.96.0.0/12"]
      }
    }
  })
}

resource "null_resource" "wait_for_talos_ready" {
  depends_on = [
    talos_machine_configuration_apply.control-planes,
    talos_machine_configuration_apply.worker-nodes
  ]

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for Talos API to be available
      until talosctl --nodes ${cidrhost(var.network_cidr, var.control_plane_first_ip)} service list; do
        echo "Waiting for Talos API..."
        sleep 10
      done

      # Wait for the Kubernetes API to be available
      until kubectl cluster-info; do
        echo "Waiting for Kubernetes API..."
        sleep 10
      done
    EOT
  }
}

resource "time_sleep" "wait_after_talos_ready" {
  depends_on      = [null_resource.wait_for_talos_ready]
  create_duration = "2m"
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    time_sleep.wait_after_talos_ready
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = cidrhost(var.network_cidr, var.control_plane_first_ip)

}

resource "terraform_data" "post_bootstrap_manifests" {
  depends_on = [
    talos_cluster_kubeconfig.this,
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
    },
    {
      name = "cilium-bgp-peering-policy"
      contents = templatefile("${path.module}/manifests/cilium/bgp-cluster-config.yaml.tpl", {
        cilium_asn = var.cilium_asn,
        router_ip  = var.router_ip != "" ? var.router_ip : var.network_gateway,
        router_asn = var.router_asn,
      })
    }
  ]

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/output/post-bootstrap-manifests/
      echo "$${jsonencode(self.input)}" | jq -r '.[] | .contents' > ${path.module}/output/post-bootstrap-manifests/$${self.input[0].name}.yaml
    EOT
  }
}

resource "null_resource" "apply_manifests" {
  depends_on = [
    talos_cluster_kubeconfig.this,
    terraform_data.post_bootstrap_manifests
  ]

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for the Kubernetes API to be fully ready
      until kubectl get nodes; do
        echo "Waiting for Kubernetes API..."
        sleep 10
      done

      # Apply the post-bootstrap manifests
      kubectl apply -f ${path.module}/output/post-bootstrap-manifests/
    EOT
  }
}

