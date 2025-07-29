resource "kubernetes_manifest" "clusterissuer_staging" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-staging"
    }
    spec = {
      acme = {
        email  = var.acme_email
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "le-account-key-staging"
        }
        solvers = [{
          dns01 = {
            cloudflare = {
              apiTokenSecretRef = {
                name = "cloudflare-api-token"
                key  = "token"
              }
            }
          }
          selector = {
            dnsZones = [var.domain]
          }
        }]
      }
    }
  }
}

resource "kubernetes_manifest" "clusterissuer_prod" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        email  = var.acme_email
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "le-account-key"
        }
        solvers = [{
          dns01 = {
            cloudflare = {
              apiTokenSecretRef = {
                name = "cloudflare-api-token"
                key  = "token"
              }
            }
          }
          selector = {
            dnsZones = [var.domain]
          }
        }]
      }
    }
  }
  depends_on = [kubernetes_manifest.clusterissuer_staging]
}

resource "kubernetes_manifest" "wildcard_certificate" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "edge-cert"
      namespace = "gateway"
    }
    spec = {
      secretName = "edge-cert"
      issuerRef = {
        name = "letsencrypt-prod"
        kind = "ClusterIssuer"
      }
      commonName = var.domain
      dnsNames   = [var.domain, "*.${var.domain}"]
      privateKey = {
        rotationPolicy = "Always"
      }
    }
  }
  depends_on = [kubernetes_manifest.clusterissuer_prod]
}