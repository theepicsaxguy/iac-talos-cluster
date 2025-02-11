resource "terraform_data" "inline-manifests" {
  depends_on = [
    data.external.kustomize_talos-ccm,
    data.external.kustomize_cilium,
  ]

  input = [
    {
      # required, prevents certificate errors
      name     = "talos-ccm"
      contents = data.external.kustomize_talos-ccm.result.manifests
    },
    {
      # required, is used as CNI and is needed for Talos to report nodes as ready
      name     = "cilium"
      contents = data.external.kustomize_cilium.result.manifests
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
}

resource "talos_machine_configuration_apply" "control-planes" {
  depends_on = [
    data.external.mac-to-ip,
    data.talos_machine_configuration.cp,
    terraform_data.inline-manifests,
  ]
  for_each = {
    for i, x in local.vm_control_planes : i => x
  }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.cp.machine_configuration
  node                        = cidrhost(var.network_cidr, each.key + var.control_plane_first_ip)
  apply_mode                  = "auto"
  endpoint                    = cidrhost(var.network_cidr, each.key + var.control_plane_first_ip)

  config_patches = [
    yamlencode({
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
        token = ""
        ca    = null
        discovery = {
          enabled = true
          registries = {
            service = {
              endpoint = "https://registry-1.docker.io"
            }
          }
        }
        inlineManifests = jsondecode(jsonencode(terraform_data.inline-manifests.output))
      }
    })
  ]
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

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.wn.machine_configuration
  node                        = cidrhost(var.network_cidr, each.key + var.worker_node_first_ip)
  apply_mode                  = "auto"
  endpoint                    = cidrhost(var.network_cidr, each.key + var.worker_node_first_ip)

  config_patches = [
    yamlencode({
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
        nodeLabels = each.value.node_labels
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
  ]
}

// Add a more comprehensive wait period for Talos nodes to be fully ready
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
    talos_machine_configuration_apply.control-planes,
    talos_machine_configuration_apply.worker-nodes,
    time_sleep.wait_after_talos_ready
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = cidrhost(var.network_cidr, var.control_plane_first_ip)

  timeouts = {
    create = "2m"
  }
}

