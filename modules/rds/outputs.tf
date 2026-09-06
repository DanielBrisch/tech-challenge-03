output "identifier" {
  description = "Identificador da instância."
  value       = aws_db_instance.this.identifier
}

output "address" {
  description = "Hostname da instância."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Porta."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Nome do banco."
  value       = aws_db_instance.this.db_name
}

output "security_group_id" {
  description = "SG da instância."
  value       = aws_security_group.this.id
}

output "connection_url" {
  description = "URL de conexão pronta para o Secret do Kubernetes."
  value       = "postgres://${var.username}:${var.password}@${aws_db_instance.this.address}:${aws_db_instance.this.port}/${aws_db_instance.this.db_name}?sslmode=require"
  sensitive   = true
}
