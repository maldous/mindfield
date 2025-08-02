variable "enabled" {
  type    = bool
  default = true
}
variable "metallb_range" {
  type = string
}
variable "kong_proxy_ip" {
  type = string
}
variable "enable_gpu_addons" {
  type        = bool
  default     = false
  description = "Enable GPU addons for MicroK8s"
}
