locals {
  tags = merge(
    var.tags,
    {
      "managed-by" = "terraform"
      "environment" = var.environment
      "owner"       = var.owner
    }
  )
}
