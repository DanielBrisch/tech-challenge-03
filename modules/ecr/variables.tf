variable "project" {
  description = "Prefixo usado nas tags."
  type        = string
}

variable "services" {
  description = "Nomes dos repositórios — um por microsserviço."
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "IMMUTABLE impede sobrescrever uma tag já publicada."
  type        = string
  default     = "IMMUTABLE"
}

variable "scan_on_push" {
  description = "Scan de vulnerabilidades do ECR a cada push (reforça o Trivy do CI)."
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Permite destruir o repositório mesmo com imagens dentro."
  type        = bool
  default     = true
}

variable "keep_last_images" {
  description = "Quantas imagens manter por repositório."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos."
  type        = map(string)
  default     = {}
}
