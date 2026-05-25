resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  namespace        = "traefik"
  create_namespace = true
  version          = var.traefik_version

  set = [
    { name = "ports.web.redirectTo.port", value = "websecure" },
    { name = "service.type", value = "LoadBalancer" },
  ]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = var.cert_manager_version

  set = [
    { name = "crds.enabled", value = "true" },
  ]
}
