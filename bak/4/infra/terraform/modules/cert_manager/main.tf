resource "kubernetes_secret" "cloudflare_api_token" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "cloudflare-api-token"
    namespace = "cert-manager"
  }
  data = {
    token = var.cf_api_token
  }
}
resource "helm_release" "cert_manager" {
  count            = var.enabled ? 1 : 0
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  repository      = "https://charts.jetstack.io"
  chart           = "cert-manager"
  version         = "~> 1.18"
  timeout         = 300
  atomic          = true
  cleanup_on_fail = true
  values = [file("${path.root}/helm-values/cert-manager.yaml")]
  set {
    name  = "installCRDs"
    value = "true"
  }
  depends_on = [
    kubernetes_secret.cloudflare_api_token[0]
  ]
}
