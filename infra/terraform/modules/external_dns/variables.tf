variable "enabled" {
  type    = bool
  default = true
}

variable "domain" {
  type = string
}

variable "zone_id" {
  type = string
}

variable "cf_api_token" {
  type      = string
  sensitive = true
}
