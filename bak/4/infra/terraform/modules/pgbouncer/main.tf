resource "helm_release" "pgbouncer" {
  count            = 0  
  name             = "pgbouncer"
  namespace        = "data"
  create_namespace = false
  repository      = "https://charts.bitnami.com/bitnami"
  chart           = "pgbouncer"
  version         = "~> 1.0"
  timeout         = 300
  atomic          = true
  cleanup_on_fail = true
  values = [file("${path.root}/helm-values/pgbouncer.yaml")]
}
