resource "time_sleep" "wait_for_network_init" {
  depends_on = [
    proxmox_virtual_environment_vm.talos-control-plane
  ]
  create_duration = "20s"
}

// Initial boot configuration for first control plane node with static IP
resource "talos_machine_configuration_apply" "init" {
  depends_on = [
    time_sleep.wait_for_network_init
  ]
  
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = cidrhost(var.network_cidr, var.control_plane_first_ip)
  machine_configuration_input = data.talos_machine_configuration.init.machine_configuration
}

resource "time_sleep" "wait_for_init" {
  depends_on = [talos_machine_configuration_apply.init]
  create_duration = "30s"
}

// Apply configuration to remaining control planes
resource "talos_machine_configuration_apply" "control-planes" {
  depends_on = [time_sleep.wait_for_init]

  for_each = {
    for i, x in local.vm_control_planes : i => x
    if i > 0  // Skip the first control plane as it's handled by init
  }

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = cidrhost(var.network_cidr, each.key + var.control_plane_first_ip)
  machine_configuration_input = yamlencode(merge(
    yamldecode(data.talos_machine_configuration.cp.machine_configuration),
    {
      machine = {
        type = "controlplane"
        network = {
          hostname = "${var.control_plane_name_prefix}-${each.key + 1}"
          interfaces = [{
            interface = "enx${lower(replace(macaddress.talos-control-plane[each.key].address, ":", ""))}"
            dhcp = false
            addresses = ["${cidrhost(var.network_cidr, each.key + var.control_plane_first_ip)}/${var.network_ip_prefix}"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.network_gateway
            }]
          }]
        }
      }
    }
  ))
}

resource "time_sleep" "wait_after_control_planes" {
  depends_on      = [talos_machine_configuration_apply.control-planes]
  create_duration = "5m"  // Increased from 3m to 5m to ensure IP changes are applied
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
  node                 = data.external.mac-to-ip.result["ip${length(local.vm_control_planes) + each.key}"]
  machine_configuration_input = yamlencode(merge(
    yamldecode(data.talos_machine_configuration.wn.machine_configuration),
    {
      machine = {
        type = "worker"
        network = {
          hostname = "${var.worker_node_name_prefix}-${each.key + 1}"
          interfaces = [{
            interface = "enx${lower(replace(macaddress.talos-worker-node[each.key].address, ":", ""))}"
            dhcp = false
            addresses = ["${cidrhost(var.network_cidr, each.key + var.worker_node_first_ip)}/${var.network_ip_prefix}"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.network_gateway
            }]
          }]
        }
      }
      cluster = {
        network = {
          dnsDomain = var.cluster_domain
          podSubnets = ["10.244.0.0/16"]
          serviceSubnets = ["10.96.0.0/12"]
        }
      }
    }
  ))
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.init,
    talos_machine_configuration_apply.control-planes,
    talos_machine_configuration_apply.worker-nodes
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = cidrhost(var.network_cidr, var.control_plane_first_ip)
}

resource "time_sleep" "wait_after_bootstrap" {
  depends_on      = [talos_machine_bootstrap.this]
  create_duration = "2m"
}

resource "null_resource" "wait_for_talos_ready" {
  depends_on = [
    time_sleep.wait_after_bootstrap,
    local_sensitive_file.export_kubeconfig
  ]

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for Talos API on the first control plane node using static IP
      until talosctl --nodes ${cidrhost(var.network_cidr, var.control_plane_first_ip)} service list; do
        echo "Waiting for Talos API..."
        sleep 10
      done

      # Verify network configuration is correct
      talosctl --nodes ${cidrhost(var.network_cidr, var.control_plane_first_ip)} get addresses

      # Wait for the Kubernetes API to be available
      until KUBECONFIG=${path.module}/output/kubeconfig kubectl cluster-info; do
        echo "Waiting for Kubernetes API..."
        sleep 10
      done
    EOT
  }
}

resource "terraform_data" "post_bootstrap_manifests" {
  depends_on = [
    null_resource.wait_for_talos_ready
  ]

  triggers_replace = {
    manifests = jsonencode([
      {
        name     = "talos-ccm"
        contents = data.kustomization_build.talos_ccm.manifests
      },
      {
        name     = "cilium"
        contents = data.kustomization_build.cilium.manifests
      },
      {
        name     = "cilium-bgp-peering-policy"
        contents = templatefile("${path.module}/manifests/cilium/bgp-cluster-config.yaml.tpl", {
          cilium_asn = var.cilium_asn,
          router_ip  = var.router_ip != "" ? var.router_ip : var.network_gateway,
          router_asn = var.router_asn,
        })
      }
    ])
  }

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/output/post-bootstrap-manifests/
      echo '${self.triggers_replace.manifests}' | jq -r '.[] | .contents' > ${path.module}/output/post-bootstrap-manifests/manifests.yaml
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
