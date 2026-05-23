# Nginx Ingress Controller — the official chart from kubernetes.github.io.
# Creates a LoadBalancer service in Azure, which provisions a public IP automatically.
# All HTTP/HTTPS traffic into the cluster flows through this controller.
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.10.0"

  set {
    name  = "controller.replicaCount"
    value = "1"
  }

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
}

# Cert Manager — issues and renews TLS certificates automatically (e.g. from Let's Encrypt).
# crds.enabled = true installs the CustomResourceDefinitions that cert-manager needs.
# Without CRDs, the ClusterIssuer and Certificate resources won't exist in the cluster.
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.15.0"

  set {
    name  = "crds.enabled"
    value = "true"
  }
}
