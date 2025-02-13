# give the vms some time to boot before scanning for ip addresses
resource "time_sleep" "wait_for_vms_to_boot" {
  depends_on = [
    proxmox_virtual_environment_vm.talos-control-plane,
    proxmox_virtual_environment_vm.talos-worker-node
  ]

  create_duration = "120s"
}

# Retry mechanism for mac-to-ip discovery
resource "null_resource" "mac_to_ip_retry" {
  depends_on = [time_sleep.wait_for_vms_to_boot]

  provisioner "local-exec" {
    command = <<-EOT
      attempts=0
      max_attempts=5
      while [ $attempts -lt $max_attempts ]; do
        if go run ${path.module}/cmd/mac-to-ip -subnet ${join(",", var.mac-to-ip_scan_subnets)} ${join(" ", concat(
    [for i, cfg in macaddress.talos-control-plane : cfg.address],
    [for i, cfg in macaddress.talos-worker-node : cfg.address]
))} > /tmp/mac-to-ip-result.json; then
          if grep -q "ip0" /tmp/mac-to-ip-result.json; then
            exit 0
          fi
        fi
        attempts=$((attempts + 1))
        if [ $attempts -lt $max_attempts ]; then
          sleep 30
        fi
      done
      echo "Failed to discover MAC addresses after $max_attempts attempts" >&2
      exit 1
    EOT
}
}

# vms are booted, use nmap to scan the network and match the known mac
# addresses with the found ip addresses
data "external" "mac-to-ip" {
  depends_on = [null_resource.mac_to_ip_retry]

  program = concat([
    "go",
    "run",
    "${path.module}/cmd/mac-to-ip",
    "-subnet",
    join(",", var.mac-to-ip_scan_subnets),
    ],
    [for i, cfg in macaddress.talos-control-plane : cfg.address],
    [for i, cfg in macaddress.talos-worker-node : cfg.address],
  )
}


output "mac-to-ip" {
  value = data.external.mac-to-ip.result
}

variable "mac-to-ip_scan_subnets" {
  description = "Subnets to scan MAC addresses for IP addresses."
  type        = list(string)
  default     = ["10.25.150.1/24"]
}
output "mac_to_ip_result" {
  value = data.external.mac-to-ip.result
}

output "control_plane_macs" {
  value = [for cfg in macaddress.talos-control-plane : cfg.address]
}

output "worker_node_macs" {
  value = [for cfg in macaddress.talos-worker-node : cfg.address]
}
