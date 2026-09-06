variable "namespace" {
  description = "Namespace onde o Argo CD é instalado."
  type        = string
  default     = "argocd"
}

variable "release_name" {
  description = "Nome do release Helm."
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Versão do chart argo-cd (argoproj/argo-helm). 10.8.0 = Argo CD v3.5.2."
  type        = string
  default     = "10.8.0"
}

variable "root_app_name" {
  description = "Nome do Application raiz (App of Apps)."
  type        = string
  default     = "toggle-master-root"
}

variable "gitops_repo_url" {
  description = "Repositório Git que o Argo CD monitora."
  type        = string
  default     = "https://github.com/DanielBrisch/tech-challenge-03.git"
}

variable "gitops_target_revision" {
  description = "Branch ou tag observada pelo Argo CD."
  type        = string
  default     = "main"
}

variable "gitops_path" {
  description = "Diretório, dentro do repositório, com as Applications filhas."
  type        = string
  default     = "argocd/applications"
}

variable "bootstrap_root_app" {
  description = "Criar o Application raiz junto com a instalação."
  type        = bool
  default     = true
}

variable "values_file" {
  description = "values.yaml alternativo. Nulo usa o values.yaml do próprio módulo."
  type        = string
  default     = null
}

variable "timeout_seconds" {
  description = "Timeout do helm_release, em segundos."
  type        = number
  default     = 900
}
