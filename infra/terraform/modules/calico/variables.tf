variable "enabled" {
  type    = bool
  default = true
}

variable "domain" {
  type = string
}

variable "cidr_allow_admin" {
  type = list(string)
}
