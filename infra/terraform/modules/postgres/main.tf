resource "helm_release" "postgres" {
  count            = var.enabled ? 1 : 0
  name             = "postgresql"
  namespace        = "data"
  create_namespace = true

  repository      = "https://charts.bitnami.com/bitnami"
  chart           = "postgresql"
  version         = "~> 16.0"
  timeout         = 300
  atomic          = true
  cleanup_on_fail = true

  values = [file("${path.root}/helm-values/postgres.yaml")]

  set {
    name  = "image.tag"
    value = var.pg_version
  }
  
  set {
    name  = "primary.persistence.size"
    value = var.storage_size
  }
}
