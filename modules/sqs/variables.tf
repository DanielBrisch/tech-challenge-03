variable "project" {
  description = "Prefixo dos nomes dos recursos."
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "Tempo que uma mensagem fica invisível após ser recebida."
  type        = number
  default     = 60
}

variable "message_retention_seconds" {
  description = "Retenção da mensagem na fila principal. Padrão: 4 dias."
  type        = number
  default     = 345600
}

variable "enable_dlq" {
  description = "Criar dead-letter queue."
  type        = bool
  default     = true
}

variable "max_receive_count" {
  description = "Tentativas antes de mandar a mensagem para a DLQ."
  type        = number
  default     = 5
}

variable "dlq_retention_seconds" {
  description = "Retenção na DLQ. Padrão: 14 dias."
  type        = number
  default     = 1209600
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos."
  type        = map(string)
  default     = {}
}
