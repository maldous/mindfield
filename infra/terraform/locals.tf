locals {
  app_name = "mindfield"
  owner = "root"
  env = "dev"
  labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of" = local.app_name
    "app.kubernetes.io/environment"= local.env
    "app.kubernetes.io/owner" = local.owner
  }
}
