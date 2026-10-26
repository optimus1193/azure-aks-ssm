locals {
  rbac_files = var.rbac_manifests_dir == null ? [] : tolist(fileset(var.rbac_manifests_dir, "*.{yaml,yml}"))

  # Split multi-document files and drop comment-only/empty documents
  rbac_documents = flatten([
    for f in local.rbac_files : [
      for doc in split("\n---", file("${var.rbac_manifests_dir}/${f}")) : doc
      if length(regexall("(?m)^apiVersion:", doc)) > 0
    ]
  ])

  # Keyed by kind/namespace/name so adding or reordering files never re-creates unrelated objects
  rbac_manifests = {
    for doc in local.rbac_documents :
    format("%s/%s/%s", yamldecode(doc).kind, try(yamldecode(doc).metadata.namespace, "_cluster"), yamldecode(doc).metadata.name) => doc
  }
}

resource "kubectl_manifest" "rbac" {
  for_each          = local.rbac_manifests
  yaml_body         = each.value
  server_side_apply = true
}
