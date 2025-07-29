resource "null_resource" "install_crds_bundle" {
  count = var.enabled ? 1 : 0
  provisioner "local-exec" {
    command = <<-EOT
      curl -fsSL https://raw.githubusercontent.com/external-secrets/external-secrets/v0.18.2/deploy/crds/bundle.yaml | microk8s kubectl apply -f -
    EOT
  }
}
resource "helm_release" "eso" {
  count            = var.enabled ? 1 : 0
  name             = "external-secrets"
  namespace        = "eso"
  create_namespace = true
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.18.2"
  values           = [file("${path.root}/helm-values/external-secrets.yaml")]
  set {
    name  = "installCRDs"
    value = "false"
  }
  depends_on = [null_resource.install_crds_bundle]
}
resource "null_resource" "wait_crds" {
  count      = var.enabled ? 1 : 0
  depends_on = [helm_release.eso]
  provisioner "local-exec" {
    command = <<-EOT
      microk8s kubectl wait --for=condition=Established crd/clustersecretstores.external-secrets.io --timeout=180s
      microk8s kubectl wait --for=condition=Established crd/externalsecrets.external-secrets.io --timeout=180s
    EOT
  }
}
resource "kubernetes_service_account_v1" "store_sa" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "k8s-store"
    namespace = "eso"
  }
  depends_on = [null_resource.wait_crds]
}
resource "kubernetes_role_v1" "store_role" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "eso-store-role"
    namespace = "eso"
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["authorization.k8s.io"]
    resources  = ["selfsubjectrulesreviews"]
    verbs      = ["create"]
  }
}
resource "kubernetes_role_binding_v1" "store_rb" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "bind-eso-store-role"
    namespace = "eso"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.store_role[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.store_sa[0].metadata[0].name
    namespace = "eso"
  }
}
resource "kubernetes_secret_v1" "cf_token_seed" {
  for_each = var.enabled ? toset(["eso", "networking"]) : []
  metadata {
    name      = "cloudflare-api-token"
    namespace = each.value
  }
  data = {
    token = var.cf_api_token
  }
  type       = "Opaque"
  depends_on = [kubernetes_role_binding_v1.store_rb]
}
resource "kubernetes_manifest" "clustersecretstore" {
  count = var.enabled && var.create_objects ? 1 : 0
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ClusterSecretStore"
    metadata   = { name = "k8s-secrets-store" }
    spec = {
      provider = {
        kubernetes = {
          remoteNamespace = "eso"
          server = {
            caProvider = {
              type      = "ConfigMap"
              name      = "kube-root-ca.crt"
              key       = "ca.crt"
              namespace = "eso"
            }
          }
          auth = { serviceAccount = { name = "k8s-store" } }
        }
      }
    }
  }
  depends_on = [kubernetes_secret_v1.cf_token_seed]
}
resource "kubernetes_manifest" "es_cf_to_certmanager" {
  count = var.enabled && var.create_objects ? 1 : 0
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata   = { name = "cloudflare-api-token", namespace = "cert-manager" }
    spec = {
      refreshInterval = "1h"
      secretStoreRef  = { name = "k8s-secrets-store", kind = "ClusterSecretStore" }
      target          = { name = "cloudflare-api-token", creationPolicy = "Owner", template = { type = "Opaque" } }
      data            = [{ secretKey = "token", remoteRef = { key = "cloudflare-api-token", property = "token" } }]
    }
  }
  depends_on = [kubernetes_manifest.clustersecretstore]
}
resource "kubernetes_manifest" "es_cf_to_networking" {
  count = var.enabled && var.create_objects ? 1 : 0
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata   = { name = "cloudflare-api-token", namespace = "networking" }
    spec = {
      refreshInterval = "1h"
      secretStoreRef  = { name = "k8s-secrets-store", kind = "ClusterSecretStore" }
      target          = { name = "cloudflare-api-token", creationPolicy = "Owner", template = { type = "Opaque" } }
      data            = [{ secretKey = "token", remoteRef = { key = "cloudflare-api-token", property = "token" } }]
    }
  }
  depends_on = [kubernetes_manifest.clustersecretstore]
}
