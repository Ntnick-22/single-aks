variable "vm_name" {
  type = string
}

variable "public_key" {
  type = string
}

variable "vpn_vnet_name" {
  type    = string
  default = "vpn-vnet"
}
