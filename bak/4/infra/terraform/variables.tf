variable "kubeconfig" {
  type    = string
  default = "~/.kube/config"
}
variable "domain" {
  type    = string
  default = "aldous.info"
}
variable "cloudflare_zone_id" {
  type    = string
  default = ""
}
variable "cloudflare_api_token" {
  type      = string
  sensitive = true
  default   = ""
}
variable "acme_email" {
  type    = string
  default = "root@aldous.info"
}
variable "metallb_range" {
  type    = string
  default = "192.168.1.250-192.168.1.254"
}
variable "kong_proxy_ip" {
  type    = string
  default = "192.168.1.251"
}
variable "postgres_version" {
  type    = string
  default = "16"
}
variable "postgres_storage" {
  type    = string
  default = "50Gi"
}
variable "opensearch_storage" {
  type    = string
  default = "100Gi"
}
variable "minio_storage" {
  type    = string
  default = "100Gi"
}
variable "grafana_storage" {
  type    = string
  default = "10Gi"
}
variable "prometheus_storage" {
  type    = string
  default = "50Gi"
}
variable "loki_storage" {
  type    = string
  default = "100Gi"
}
variable "tempo_storage" {
  type    = string
  default = "100Gi"
}
variable "enable_gpu_addons" {
  type        = bool
  default     = false
  description = "Enable GPU addons for MicroK8s"
}
