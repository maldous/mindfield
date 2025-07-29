resource "helm_release" "minio_tenant" {
  count            = var.enabled ? 1 : 0
  name             = "minio-tenant"
  namespace        = "minio"
  create_namespace = true

  repository      = "https://operator.min.io"
  chart           = "tenant"
  version         = "~> 6.0"
  timeout         = 300
  atomic          = true
  cleanup_on_fail = true

  values = [file("${path.root}/helm-values/minio-tenant.yaml")]

  set {
    name  = "tenant.pools[0].size"
    value = var.storage_size
  }
}
