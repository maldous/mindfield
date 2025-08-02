resource "null_resource" "gateway_api_crds" {
  count = var.enabled ? 1 : 0
  provisioner "local-exec" {
    command = "microk8s kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml"
  }
}
resource "helm_release" "kong" {
  count            = var.enabled ? 1 : 0
  name             = "kong"
  namespace        = "gateway"
  create_namespace = true
  repository      = "https://charts.konghq.com"
  chart           = "kong"
  version         = "~> 2.38"
  timeout         = 600
  atomic          = true
  cleanup_on_fail = true
  values = [file("${path.root}/helm-values/kong.yaml")]
  set {
    name  = "proxy.loadBalancerIP"
    value = var.proxy_ip
  }
  depends_on = [
    var.cert_dependency,
    null_resource.gateway_api_crds
  ]
}
resource "time_sleep" "wait_for_kong" {
  count           = var.enabled ? 1 : 0
  depends_on      = [helm_release.kong]
  create_duration = "60s"
}
resource "kubernetes_manifest" "kong_gatewayclass" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata = {
      name = "kong"
    }
    spec = {
      controllerName = "konghq.com/kic-gateway-controller"
    }
  }
  depends_on = [time_sleep.wait_for_kong]
}
resource "kubernetes_manifest" "kong_gateway" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "edge"
      namespace = "gateway"
    }
    spec = {
      gatewayClassName = "kong"
      listeners = [
        {
          name     = "https"
          protocol = "HTTPS"
          port     = 443
          tls = {
            mode = "Terminate"
            certificateRefs = [{
              name = "edge-cert"
            }]
          }
        },
        {
          name     = "http"
          protocol = "HTTP"
          port     = 80
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
        }
      ]
    }
  }
  depends_on = [kubernetes_manifest.kong_gatewayclass]
}
resource "kubernetes_manifest" "kong_global_rate_limit" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "configuration.konghq.com/v1"
    kind       = "KongClusterPlugin"
    metadata = {
      name = "global-rate"
      labels = {
        global = "true"
      }
    }
    plugin = "rate-limiting"
    config = {
      minute = 100
      policy = "local"
    }
  }
  depends_on = [time_sleep.wait_for_kong]
}
