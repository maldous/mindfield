variable "kubeconfig" {
  description = "Path to kubeconfig"
  type        = string
  default     = "~/.kube/config"
}

variable "domain" {
  description = "Primary DNS zone"
  type        = string
  default     = "aldous.info"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for domain"
  type        = string
  default     = ""
}

variable "cloudflare_email" {
  description = "Cloudflare account email (if needed)"
  type        = string
  default     = ""
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:Read + DNS:Edit"
  type        = string
  sensitive   = true
  default     = ""
}

variable "acme_email" {
  description = "Email for Let's Encrypt ACME registration"
  type        = string
  default     = "root@aldous.info"
}

variable "metallb_range" {
  description = "MetalLB address pool"
  type        = string
  default     = "192.168.1.250-192.168.1.254"
}

variable "kong_proxy_ip" {
  description = "Static LB IP for Kong proxy"
  type        = string
  default     = "192.168.1.251"
}

variable "cidr_allow_admin" {
  description = "CIDR(s) allowed to access admin /health/metrics endpoints"
  type        = list(string)
  default     = ["192.168.0.0/16"]
}

variable "postgres_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

variable "postgres_storage" {
  description = "PostgreSQL PVC size"
  type        = string
  default     = "50Gi"
}

variable "opensearch_storage" {
  description = "OpenSearch PVC size"
  type        = string
  default     = "100Gi"
}

variable "minio_storage" {
  description = "MinIO tenant total raw size"
  type        = string
  default     = "100Gi"
}

variable "grafana_storage"  { 
  type = string
  default = "10Gi"  
}

variable "prometheus_storage" { 
  type = string
  default = "50Gi" 
}

variable "loki_storage"     { 
  type = string
  default = "100Gi" 
}

variable "tempo_storage"    { 
  type = string
  default = "100Gi" 
}

# Create ESO objects (ClusterSecretStore, ExternalSecret) after CRDs exist.
variable "external_secrets_create_objects" {
  type        = bool
  description = "Whether to create ESO ClusterSecretStore and ExternalSecrets"
  default     = false
}
