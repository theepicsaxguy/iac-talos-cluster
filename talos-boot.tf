resource "talos_machine_configuration_apply" "control-planes" {
  depends_on = [
    data.external.mac-to-ip,
    data.talos_machine_configuration.cp
  ]

  for_each = {
    for i, x in local.vm_control_planes : i => x
  }

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = data.external.mac-to-ip.result["ip${each.key}"]
  machine_configuration_input = yamlencode(merge(
    yamldecode(data.talos_machine_configuration.cp.machine_configuration),
    {
      machine = {
        type = "controlplane"
        certSANs = [local.cluster_endpoint]
        ca = base64encode(talos_machine_secrets.this.client_configuration.ca_certificate)
        acceptedCAs = [
          base64encode(talos_machine_secrets.this.client_configuration.ca_certificate)
        ]
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
        install = {
          disk = var.install_disk_device
        }
        kubelet = {
          extraArgs = {
            "node-ip" = cidrhost(var.network_cidr, each.key + var.control_plane_first_ip)
          }
        }
      }
      cluster = {
        id = 1
        secret = talos_machine_secrets.this.machine_secrets.cluster.secret
        controlPlane = {
          endpoint = "https://${local.cluster_endpoint}:6443"
        }
        clusterName = var.cluster_name
        network = {
          dnsDomain = var.cluster_domain
          podSubnets = ["10.244.0.0/16"]
          serviceSubnets = ["10.96.0.0/12"]
        }
      }
    }
  ))
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
  node                 = data.external.mac-to-ip.result["ip${length(local.vm_control_planes) + each.key}"]
  machine_configuration_input = yamlencode(merge(
    yamldecode(data.talos_machine_configuration.wn.machine_configuration),
    {
      machine = {
        type = "worker"
        ca = base64encode(talos_machine_secrets.this.client_configuration.ca_certificate)
        acceptedCAs = [
          base64encode(talos_machine_secrets.this.client_configuration.ca_certificate)
        ]
        certSANs = [local.cluster_endpoint]
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
        install = {
          disk = var.install_disk_device
        }
      }
      cluster = {
        secret = talos_machine_secrets.this.machine_secrets.cluster.secret
        controlPlane = {
          endpoint = "https://${local.cluster_endpoint}:6443"
        }
        clusterName = var.cluster_name
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
    talos_machine_configuration_apply.control-planes,
    talos_machine_configuration_apply.worker-nodes
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = data.external.mac-to-ip.result["ip0"]
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
      # Wait for Talos API to be available using discovered IP
      until talosctl --nodes ${data.external.mac-to-ip.result["ip0"]} service list; do
        echo "Waiting for Talos API..."
        sleep 10
      done

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
