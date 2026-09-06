variable "region" {
  description = "Região AWS. O AWS Academy normalmente só libera us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefixo dos nomes dos recursos."
  type        = string
  default     = "toggle-master"
}

variable "environment" {
  description = "Nome do ambiente, usado nas tags."
  type        = string
  default     = "lab"
}

variable "lab_role_name" {
  description = <<-EOT
    Role existente usada pelo cluster e pelos nós. No AWS Academy é LabRole.
    Em conta pessoal, troque por roles criadas via Terraform.
  EOT
  type        = string
  default     = "LabRole"
}

variable "vpc_cidr" {
  description = "CIDR da VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Quantas AZs usar. Mínimo 2 para o EKS."
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Um NAT Gateway só, em vez de um por AZ. Economiza ~US$ 32/mês por AZ."
  type        = bool
  default     = true
}

variable "cluster_version" {
  description = "Versão do Kubernetes no EKS."
  type        = string
  default     = "1.34"
}

variable "node_instance_types" {
  description = "Tipos de instância dos nós."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Nós desejados."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Nós no mínimo."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Nós no máximo."
  type        = number
  default     = 4
}

variable "db_instance_class" {
  description = "Classe das instâncias RDS."
  type        = string
  default     = "db.t3.micro"
}

variable "db_storage_encrypted" {
  description = "Criptografia em repouso no RDS. Ponha false se o laboratório bloquear KMS."
  type        = bool
  default     = true
}

variable "redis_node_type" {
  description = "Tipo do nó do ElastiCache."
  type        = string
  default     = "cache.t3.micro"
}

variable "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB esperado pelo analytics-service."
  type        = string
  default     = "ToggleMasterAnalytics"
}
