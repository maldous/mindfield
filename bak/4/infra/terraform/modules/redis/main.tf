resource "helm_release" "redis" {
  count            = var.enabled ? 1 : 0
  name             = "redis"
  namespace        = "data"
  create_namespace = false
  repository      = "https://charts.bitnami.com/bitnami"
  chart           = "redis"
  version         = "~> 20.0"
  timeout         = 300
  atomic          = true
  cleanup_on_fail = true
  values = [file("${path.root}/helm-values/redis.yaml")]
}
