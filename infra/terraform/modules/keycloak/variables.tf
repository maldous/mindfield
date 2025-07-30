variable "enabled" {
  type    = bool
  default = false
}

variable "postgres_dependency" {
  description = "Dependency on PostgreSQL module"
  type        = any
  default     = null
}
