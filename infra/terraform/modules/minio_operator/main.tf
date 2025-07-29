resource "helm_release" "minio_operator" {
  count            = var.enabled ? 1 : 0
  name             = "minio-operator"
  namespace        = "minio-operator"
  create_namespace = true

  repository      = "https://operator.min.io"
  chart           = "operator"
  version         = "~> 6.0"
  timeout         = 300
  atomic          = true
  cleanup_on_fail = true

  values = [file("${path.root}/helm-values/minio-operator.yaml")]
}
