variable "enabled" {
  type    = bool
  default = true
}
variable "domain" {
  type = string
}
variable "acme_email" {
  type = string
}
variable "cf_zone_id" {
  type = string
}
variable "cf_api_token" {
  type      = string
  sensitive = true
}
