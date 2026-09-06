
output "cluster_name" {
  description = "Nome do cluster EKS."
  value       = module.eks.cluster_name
}

output "update_kubeconfig_command" {
  description = "Comando para apontar o kubectl para o cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  description = "ID da VPC."
  value       = module.networking.vpc_id
}

output "ecr_registry_url" {
  description = "Host do registry ECR. Use nos secrets do GitHub Actions."
  value       = module.ecr.registry_url
}

output "ecr_repository_urls" {
  description = "Mapa serviço -> URL do repositório ECR."
  value       = module.ecr.repository_urls
}

output "sqs_queue_url" {
  description = "URL da fila SQS."
  value       = module.sqs.queue_url
}

output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB."
  value       = module.dynamodb.table_name
}

output "rds_endpoints" {
  description = "Endpoints das 3 instâncias PostgreSQL."
  value       = { for k, m in module.rds : k => m.address }
}

output "redis_endpoint" {
  description = "Endpoint do Redis."
  value       = module.elasticache.address
}

output "secrets_env" {
  description = "Conteúdo pronto para o kubectl create secret --from-env-file."
  sensitive   = true
  value       = <<-EOT
    AUTH_DATABASE_URL=${module.rds["auth"].connection_url}
    FLAG_DATABASE_URL=${module.rds["flags"].connection_url}
    TARGETING_DATABASE_URL=${module.rds["targeting"].connection_url}
    REDIS_URL=${module.elasticache.connection_url}
    AWS_SQS_URL=${module.sqs.queue_url}
    MASTER_KEY=${random_password.master_key.result}
    SERVICE_API_KEY=tm_key_local_dev
  EOT
}
