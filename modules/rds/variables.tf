variable "project" {
  description = "Prefixo dos nomes dos recursos."
  type        = string
}

variable "name" {
  description = "Sufixo que identifica esta instância (ex: auth, flags, targeting)."
  type        = string
}

variable "db_name" {
  description = "Nome do banco criado na instância (ex: auth_db)."
  type        = string
}

variable "username" {
  description = "Usuário master."
  type        = string
  default     = "toggle"
}

variable "password" {
  description = "Senha do usuário master."
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC onde a instância será criada."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets privadas do subnet group."
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDRs autorizados a conectar na porta 5432. Normalmente o CIDR da VPC."
  type        = list(string)
}

variable "engine_version" {
  description = "Versão major do PostgreSQL. A AWS resolve a minor."
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "Classe da instância. db.t3.micro é o que o Academy libera."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Armazenamento inicial, em GB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Teto do autoscaling de storage, em GB. 0 desliga."
  type        = number
  default     = 0
}

variable "storage_encrypted" {
  description = "Criptografia em repouso com a chave KMS padrão do RDS. Desligue se o laboratório bloquear KMS."
  type        = bool
  default     = true
}

variable "multi_az" {
  description = "Alta disponibilidade entre AZs. Dobra o custo — falso em laboratório."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Não criar snapshot final ao destruir."
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Dias de retenção de backup. 0 desliga backups automáticos."
  type        = number
  default     = 0
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos."
  type        = map(string)
  default     = {}
}
