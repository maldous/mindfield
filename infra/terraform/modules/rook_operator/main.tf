# Create namespace with privileged security context for Rook
resource "kubernetes_namespace_v1" "rook_ceph" {
  count = var.enabled ? 1 : 0
  metadata {
    name = "rook-ceph"
    labels = {
      "pod-security.kubernetes.io/enforce"         = "privileged"
      "pod-security.kubernetes.io/enforce-version" = "latest"
      "pod-security.kubernetes.io/audit"           = "privileged"
      "pod-security.kubernetes.io/warn"            = "privileged"
    }
  }
}

resource "helm_release" "rook_operator" {
  count            = var.enabled ? 1 : 0
  name             = "rook-ceph"
  namespace        = "rook-ceph"
  create_namespace = false

  repository      = "https://charts.rook.io/release"
  chart           = "rook-ceph"
  version         = "~> 1.15"
  timeout         = 600
  atomic          = true
  cleanup_on_fail = true

  values = [file("${path.root}/helm-values/rook-operator.yaml")]
  
  depends_on = [kubernetes_namespace_v1.rook_ceph]
}
