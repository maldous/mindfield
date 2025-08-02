output "staging_issuer_name" {
  value = var.enabled ? kubernetes_manifest.clusterissuer_staging[0].manifest.metadata.name : null
}
output "prod_issuer_name" {
  value = var.enabled ? kubernetes_manifest.clusterissuer_prod[0].manifest.metadata.name : null
}
output "certificate_secret_name" {
  value = var.enabled ? kubernetes_manifest.wildcard_certificate[0].manifest.spec.secretName : null
}
