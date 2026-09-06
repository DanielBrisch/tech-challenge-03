output "repository_urls" {
  description = "Mapa serviço -> URL do repositório."
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "registry_url" {
  description = "Host do registry (<conta>.dkr.ecr.<regiao>.amazonaws.com)."
  value       = length(var.services) > 0 ? split("/", values(aws_ecr_repository.this)[0].repository_url)[0] : null
}
