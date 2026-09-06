data "aws_region" "current" {}

output "cluster_name" {
  description = "Nome do cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint da API do Kubernetes."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "CA do cluster, em base64."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "Versão do Kubernetes em execução."
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = <<-EOT
    Security group que o EKS cria e anexa ao control plane E aos nós do managed
    node group. É este — e não um SG criado à mão — que identifica o tráfego
    vindo dos nós.
  EOT
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "update_kubeconfig_command" {
  description = "Comando para configurar o kubectl."
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.region} --name ${aws_eks_cluster.this.name}"
}
