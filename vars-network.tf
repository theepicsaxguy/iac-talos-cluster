variable "network_ip_prefix" {
  description = "Network IP network prefix"
  type        = number
  default     = 24
}

variable "network_cidr" {
  description = "Network address in CIDR notation"
  type        = string
  default     = "10.25.150.0/24"
}

variable "network_gateway" {
  description = "Gateway of the network"
  type        = string
  default     = "10.25.150.1"
}

variable "router_ip" {
  description = "IP address of the router, uses network_gateway as default value"
  type        = string
  default     = "10.25.150.1"
}

variable "router_asn" {
  description = "Router ASN for use with Cilium BGP"
  type        = number
  default     = 64501
}

variable "cilium_asn" {
  type    = number
  default = 64500
}
