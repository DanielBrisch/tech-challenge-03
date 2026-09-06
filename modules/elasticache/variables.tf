variable "project" {
  description = "Prefixo dos nomes dos recursos."
  type        = string
}

variable "vpc_id" {
  description = "VPC onde o cluster será criado."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets privadas do subnet group."
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDRs autorizados a conectar na porta 6379. Normalmente o CIDR da VPC."
  type        = list(string)
}

variable "node_type" {
  description = "Tipo do nó. cache.t3.micro é o que o Academy libera."
  type        = string
  default     = "cache.t3.micro"
}

variable "engine_version" {
  description = "Versão do Redis."
  type        = string
  default     = "7.1"
}

variable "parameter_group_name" {
  description = "Parameter group. Precisa casar com a major do engine_version."
  type        = string
  default     = "default.redis7"
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos."
  type        = map(string)
  default     = {}
}
