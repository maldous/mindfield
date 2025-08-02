locals {
  base_addons = [
    "dns",
    "rbac",
    "helm3",
    "metrics-server",
    "hostpath-storage",
    "metallb:${var.metallb_range}",
  ]
  gpu_addons = var.enable_gpu_addons ? ["gpu"] : []
  addons_list = concat(local.base_addons, local.gpu_addons)
}
resource "null_resource" "addons" {
  count = var.enabled ? 1 : 0
  triggers = {
    addons_hash      = join(",", local.addons_list)
    metallb_range    = var.metallb_range
    kong_proxy_ip    = var.kong_proxy_ip
    enable_gpu_addons = var.enable_gpu_addons
  }
  provisioner "local-exec" {
    command = <<-EOT
      microk8s status --wait-ready
      microk8s enable ${join(" ", local.addons_list)}
    EOT
  }
}
