variable "region" {
  description = "Região AWS."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefixo usado nas tags."
  type        = string
  default     = "toggle-master"
}

variable "cluster_name" {
  description = "Nome do cluster EKS criado em ../infra."
  type        = string
  default     = "toggle-master-eks"
}

variable "install_ingress_nginx" {
  description = "Instalar o Ingress Controller. Provisiona um NLB (tem custo)."
  type        = bool
  default     = true
}

variable "ingress_nginx_chart_version" {
  description = "Versão do chart ingress-nginx."
  type        = string
  default     = "4.15.1"
}

variable "argocd_namespace" {
  description = "Namespace do Argo CD."
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Versão do chart argo-cd."
  type        = string
  default     = "10.8.0"
}

variable "gitops_repo_url" {
  description = "Repositório Git que o Argo CD monitora."
  type        = string
  default     = "https://github.com/FIAP-Teach-Challenge-2/toggle-master-infra.git"
}

variable "gitops_target_revision" {
  description = "Branch observada pelo Argo CD."
  type        = string
  default     = "main"
}

variable "bootstrap_root_app" {
  description = <<-EOT
    Registrar o Application raiz (App of Apps) junto com a instalação.
    Ponha false para instalar o Argo CD antes de o repositório de manifestos
    existir — senão a Application raiz nasce em ComparisonError.
  EOT
  type        = bool
  default     = true
}
