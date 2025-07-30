variable "enabled" {
  type    = bool
  default = false
}

variable "proxy_ip" {
  description = "LoadBalancer IP for Kong proxy"
  type        = string
  default     = "192.168.1.251"
}

variable "cert_dependency" {
  description = "Dependency on cert issuers module"
  type        = any
  default     = null
}
