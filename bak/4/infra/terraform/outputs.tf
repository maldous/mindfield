output "domain" {
  value = var.domain
}
output "kong_proxy_ip" {
  value = var.kong_proxy_ip
}
output "urls" {
  value = {
    web          = "https://${var.domain}"
    grafana      = "https://grafana.${var.domain}"
    prometheus   = "https://prometheus.${var.domain}"
    alertmanager = "https://alertmanager.${var.domain}"
    opensearch   = "https://search.${var.domain}"
    sonarqube    = "https://sonar.${var.domain}"
    mailhog      = "https://mailhog.${var.domain}"
    pgadmin      = "https://pgadmin.${var.domain}"
    kuma         = "https://ops.${var.domain}"
  }
}
