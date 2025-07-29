resource "kubernetes_secret" "cloudflare_api_token" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "cloudflare-api-token"
    namespace = "networking"
  }
  data = {
    token = var.cf_api_token
  }
}

resource "helm_release" "external_dns" {
  count            = var.enabled ? 1 : 0
  name             = "external-dns"
  namespace        = "networking"
  create_namespace = true
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = "~> 1.18"
  timeout          = 300
  atomic           = true
  cleanup_on_fail  = true
  values           = [file("${path.root}/helm-values/external-dns.yaml")]
  set {
    name  = "extraArgs[0]"
    value = "--zone-id-filter=${var.zone_id}"
  }
  set {
    name  = "domainFilters[0]"
    value = var.domain
  }
  depends_on = [kubernetes_secret.cloudflare_api_token]
}
