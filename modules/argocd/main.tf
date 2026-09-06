
locals {
  root_app = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = var.root_app_name
      namespace  = var.namespace
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_target_revision
        path           = var.gitops_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }
}

resource "helm_release" "argocd" {
  name             = var.release_name
  namespace        = var.namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  wait    = true
  timeout = var.timeout_seconds

  values = [file(coalesce(var.values_file, "${path.module}/values.yaml"))]
}

resource "helm_release" "bootstrap" {
  count = var.bootstrap_root_app ? 1 : 0

  name      = "${var.release_name}-bootstrap"
  namespace = var.namespace
  chart     = "${path.module}/charts/bootstrap"

  values = [yamlencode({ manifests = [local.root_app] })]

  depends_on = [helm_release.argocd]
}
