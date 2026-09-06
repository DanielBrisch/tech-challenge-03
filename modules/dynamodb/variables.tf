variable "project" {
  description = "Prefixo usado nas tags."
  type        = string
}

variable "table_name" {
  description = "Nome da tabela. O analytics-service espera ToggleMasterAnalytics."
  type        = string
  default     = "ToggleMasterAnalytics"
}

variable "hash_key" {
  description = "Chave de partição."
  type        = string
  default     = "event_id"
}

variable "billing_mode" {
  description = "PAY_PER_REQUEST ou PROVISIONED."
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "point_in_time_recovery" {
  description = "Backup contínuo. Custa a mais — falso em laboratório."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos."
  type        = map(string)
  default     = {}
}
