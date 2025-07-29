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
