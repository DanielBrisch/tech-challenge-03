
resource "helm_release" "ingress_nginx" {
  count = var.install_ingress_nginx ? 1 : 0

  name             = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.ingress_nginx_chart_version

  values = [yamlencode({
    controller = {
      service = {
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
        }
      }
      replicaCount = 1
      resources = {
        requests = { cpu = "100m", memory = "128Mi" }
      }
    }
  })]

  wait    = true
  timeout = 900
}

module "argocd" {
  source = "../modules/argocd"

  namespace     = var.argocd_namespace
  chart_version = var.argocd_chart_version

  gitops_repo_url        = var.gitops_repo_url
  gitops_target_revision = var.gitops_target_revision
  bootstrap_root_app     = var.bootstrap_root_app

  depends_on = [helm_release.ingress_nginx]
}
