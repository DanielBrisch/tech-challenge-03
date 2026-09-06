variable "project" {
  description = "Prefixo dos nomes dos recursos."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR da VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Quantas AZs usar. O EKS exige no mínimo 2."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "O EKS exige subnets em pelo menos 2 zonas de disponibilidade."
  }
}

variable "single_nat_gateway" {
  description = "Um único NAT Gateway para todas as AZs (mais barato) em vez de um por AZ."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos."
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = <<-EOT
    Nome do cluster EKS, usado na tag kubernetes.io/cluster/<nome> das subnets.
    Recebido como string (e não como output do módulo eks) de propósito: assim
    o valor é conhecido em plan time e não há ciclo entre rede e cluster.
  EOT
  type        = string
}
