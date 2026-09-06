output "address" {
  description = "Endpoint do nó Redis."
  value       = aws_elasticache_cluster.this.cache_nodes[0].address
}

output "port" {
  description = "Porta."
  value       = aws_elasticache_cluster.this.cache_nodes[0].port
}

output "connection_url" {
  description = "URL pronta para o Secret do Kubernetes."
  value       = "redis://${aws_elasticache_cluster.this.cache_nodes[0].address}:${aws_elasticache_cluster.this.cache_nodes[0].port}"
}

output "security_group_id" {
  description = "SG do cluster."
  value       = aws_security_group.this.id
}
