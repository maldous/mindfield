resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = "cert-manager"
  }
  data = {
    token = var.cf_api_token
  }
}

###############################################################################
# Install cert‑manager CRDs via Helm
###############################################################################
resource "helm_release" "cert_manager" {
  count            = var.enabled ? 1 : 0
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.18.2"

  values = [file("${path.root}/helm-values/cert-manager.yaml")]

  set {
    name  = "installCRDs"
    value = "true"
  }
  depends_on = [
    kubernetes_secret.cloudflare_api_token
  ]
}

###############################################################################
# Apply ClusterIssuer and Certificate with kubectl (avoids CRD-plan errors)
###############################################################################
resource "null_resource" "clusterissuer_staging" {
  count = var.enabled ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      microk8s kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    email: ${var.acme_email}
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: le-account-key-staging
    solvers:
    - dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: token
      selector:
        dnsZones:
        - ${var.domain}
EOF
    EOT
  }

  depends_on = [helm_release.cert_manager]
}

resource "null_resource" "clusterissuer_prod" {
  count = var.enabled ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      microk8s kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: ${var.acme_email}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: le-account-key
    solvers:
    - dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: token
      selector:
        dnsZones:
        - ${var.domain}
EOF
    EOT
  }

  depends_on = [null_resource.clusterissuer_staging]
}

resource "null_resource" "wildcard_certificate" {
  count = var.enabled ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      microk8s kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: edge-cert
  namespace: gateway
spec:
  secretName: edge-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: ${var.domain}
  dnsNames:
  - ${var.domain}
  - "*.${var.domain}"
  privateKey:
    rotationPolicy: Always
EOF
    EOT
  }

  depends_on = [null_resource.clusterissuer_prod]
}
