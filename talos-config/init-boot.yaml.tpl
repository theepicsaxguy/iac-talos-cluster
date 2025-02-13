machine:
  install:
    disk: ${install_disk_device}
    image: ${install_image_url}
  network:
    hostname: ${hostname}
    interfaces:
      - interface: ${network_interface}
        dhcp: false
        addresses:
          - ${ipv4_local}/${network_ip_prefix}
        routes:
          - network: 0.0.0.0/0
            gateway: ${network_gateway}

cluster:
  network:
    cni:
      name: none