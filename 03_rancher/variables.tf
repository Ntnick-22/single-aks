variable "vm_name" {
  type = string
}

variable "public_key" {
  type = string
}

# Cloudflare Tunnel connector token — injected via TF_VAR_cloudflare_tunnel_token
# from a GitHub Actions secret, never committed to terraform.tfvars.
variable "cloudflare_tunnel_token" {
  type      = string
  sensitive = true
}
