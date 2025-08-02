output "enabled" {
  value = var.enabled
}
output "cloudflare_api_token" {
  value     = var.cf_api_token
  sensitive = true
}
