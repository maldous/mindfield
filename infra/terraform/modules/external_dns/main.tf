resource "helm_release" "external_dns" {
  count            = var.enabled ? 1 : 0
  name             = "external-dns"
  namespace        = "networking"
  create_namespace = true

  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.18.0"

  values = [file("${path.root}/helm-values/external-dns.yaml")]

  set {
    name  = "provider.name"
    value = "cloudflare"
  }
  set {
    name  = "extraArgs[0]"
    value = "--zone-id-filter=${var.zone_id}"
  }
  set {
    name  = "domainFilters[0]"
    value = var.domain
  }
  set {
    name  = "policy"
    value = "upsert-only"
  }
  set {
    name  = "sources[0]"
    value = "ingress"
  }
}
