# Traefik and ArgoCD used to have enable_* toggles (count = 0/1). They are now core offerings
# without count. These blocks keep existing installs in place instead of destroying and recreating them.

moved {
  from = helm_release.traefik[0]
  to   = helm_release.traefik
}

moved {
  from = helm_release.argocd[0]
  to   = helm_release.argocd
}

moved {
  from = bcrypt_hash.argocd_admin[0]
  to   = bcrypt_hash.argocd_admin
}

moved {
  from = time_static.argocd_admin_password[0]
  to   = time_static.argocd_admin_password
}
