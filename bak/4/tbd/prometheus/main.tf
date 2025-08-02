# Placeholder. Implement helm_release / manifests when enabling.
locals {
  noop = true
}

# Example (disabled): null_resource just to be structurally valid
resource "null_resource" "noop" {
  count = var.enabled ? 1 : 0
}
