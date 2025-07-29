data "kubernetes_service" "apiserver" {
  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}
locals {
  namespaces = [
    "cert-manager",
    "networking",
    "eso",
    "gateway",
    "auth",
    "data",
    "monitoring",
    "search",
    "devtools",
    "minio",
  ]
  apiserver_cidr = "${data.kubernetes_service.apiserver.spec[0].cluster_ip}/32"
  node_api_ports = [6443, 16443]
  webhook_port   = 10250
}
resource "kubernetes_namespace_v1" "ns" {
  count = var.enabled ? length(local.namespaces) : 0
  metadata {
    name = local.namespaces[count.index]
    labels = {
      "pod-security.kubernetes.io/enforce"         = "baseline"
      "pod-security.kubernetes.io/enforce-version" = "latest"
      "pod-security.kubernetes.io/audit"           = "baseline"
      "pod-security.kubernetes.io/warn"            = "baseline"
    }
  }
}
resource "kubernetes_network_policy_v1" "default_deny" {
  depends_on = [kubernetes_namespace_v1.ns]
  for_each   = var.enabled ? toset(local.namespaces) : []
  metadata {
    name      = "default-deny-all"
    namespace = each.value
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}
resource "kubernetes_network_policy_v1" "allow_dns" {
  depends_on = [kubernetes_namespace_v1.ns]
  for_each   = var.enabled ? toset(local.namespaces) : []
  metadata {
    name      = "allow-dns"
    namespace = each.value
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
      ports {
        port     = 53
        protocol = "UDP"
      }
      ports {
        port     = 53
        protocol = "TCP"
      }
    }
  }
}
resource "kubernetes_network_policy_v1" "allow_apiserver_service_egress" {
  depends_on = [kubernetes_namespace_v1.ns]
  for_each   = var.enabled ? toset(local.namespaces) : []
  metadata {
    name      = "allow-apiserver-egress"
    namespace = each.value
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    egress {
      to {
        ip_block {
          cidr = local.apiserver_cidr
        }
      }
      ports {
        port     = 443
        protocol = "TCP"
      }
    }
  }
}
resource "kubernetes_network_policy_v1" "allow_apiserver_node_egress" {
  depends_on = [kubernetes_namespace_v1.ns]
  for_each   = var.enabled ? toset(local.namespaces) : []
  metadata {
    name      = "allow-apiserver-node-egress"
    namespace = each.value
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    dynamic "egress" {
      for_each = var.cidr_allow_admin
      content {
        to {
          ip_block {
            cidr = egress.value
          }
        }
        dynamic "ports" {
          for_each = toset(local.node_api_ports)
          content {
            port     = ports.value
            protocol = "TCP"
          }
        }
      }
    }
  }
}
resource "kubernetes_network_policy_v1" "cm_egress_internet" {
  depends_on = [kubernetes_namespace_v1.ns]
  count      = var.enabled ? 1 : 0
  metadata {
    name      = "allow-egress-internet"
    namespace = "cert-manager"
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
    }
  }
}
resource "kubernetes_network_policy_v1" "extdns_egress_internet" {
  depends_on = [kubernetes_namespace_v1.ns]
  count      = var.enabled ? 1 : 0
  metadata {
    name      = "allow-egress-internet"
    namespace = "networking"
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
    }
  }
}
resource "kubernetes_network_policy_v1" "eso_egress_internet" {
  depends_on = [kubernetes_namespace_v1.ns]
  count      = var.enabled ? 1 : 0
  metadata {
    name      = "allow-egress-internet"
    namespace = "eso"
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        port     = 443
        protocol = "TCP"
      }
      ports {
        port     = 80
        protocol = "TCP"
      }
    }
  }
}
resource "kubernetes_network_policy_v1" "webhook_ingress_cert_manager" {
  depends_on = [kubernetes_namespace_v1.ns]
  count      = var.enabled ? 1 : 0
  metadata {
    name      = "allow-webhook-ingress"
    namespace = "cert-manager"
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress"]
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
      dynamic "from" {
        for_each = var.cidr_allow_admin
        content {
          ip_block {
            cidr = from.value
          }
        }
      }
      ports {
        port     = local.webhook_port
        protocol = "TCP"
      }
    }
  }
}
resource "kubernetes_network_policy_v1" "webhook_ingress_eso" {
  depends_on = [kubernetes_namespace_v1.ns]
  count      = var.enabled ? 1 : 0
  metadata {
    name      = "allow-webhook-ingress"
    namespace = "eso"
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress"]
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
      dynamic "from" {
        for_each = var.cidr_allow_admin
        content {
          ip_block {
            cidr = from.value
          }
        }
      }
      ports {
        port     = local.webhook_port
        protocol = "TCP"
      }
    }
  }
}
