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

# Your WireGuard client's PUBLIC key only — never the private key.
# Generate locally: wg genkey | tee privatekey | wg pubkey > publickey
variable "wg_client_public_key" {
  type = string
}
