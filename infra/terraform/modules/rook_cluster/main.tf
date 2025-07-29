resource "helm_release" "rook_cluster" {
  count            = var.enabled ? 1 : 0
  name             = "rook-ceph-cluster"
  namespace        = "rook-ceph"
  create_namespace = false

  repository      = "https://charts.rook.io/release"
  chart           = "rook-ceph-cluster"
  version         = "~> 1.15"
  timeout         = 600
  atomic          = true
  cleanup_on_fail = true

  values = [file("${path.root}/helm-values/rook-cluster.yaml")]
}
