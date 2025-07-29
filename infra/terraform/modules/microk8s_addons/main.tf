locals {
  addons_list = [
    "dns",
    "rbac",
    "helm3",
    "metrics-server",
    "metallb:${var.metallb_range}",
    "gpu",
  ]
}

resource "null_resource" "addons" {
  count = var.enabled ? 1 : 0

  triggers = {
    addons_hash = join(",", local.addons_list)
  }

  provisioner "local-exec" {
    command = <<-EOT
      microk8s status --wait-ready
      microk8s enable ${join(" ", local.addons_list)}
    EOT
  }
}
