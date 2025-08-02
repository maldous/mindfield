variable "enabled" {
  type    = bool
  default = false
}
variable "storage_size" {
  type    = string
  default = "50Gi"
}
variable "pg_version" {
  type    = string
  default = "16"
}
