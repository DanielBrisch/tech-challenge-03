output "argocd_namespace" {
  description = "Namespace do Argo CD."
  value       = module.argocd.namespace
}

output "argocd_admin_password_command" {
  description = "Comando para recuperar a senha inicial do admin."
  value       = module.argocd.admin_password_command
}

output "argocd_port_forward_command" {
  description = "Comando para abrir a UI do Argo CD."
  value       = module.argocd.port_forward_command
}

output "next_steps" {
  description = "O que fazer depois deste apply."
  value       = <<-EOT
    1. Criar o Secret que os 5 serviços consomem:
         terraform -chdir=../infra output -raw secrets_env > secrets.local.env
         kubectl create namespace toggle-master
         kubectl -n toggle-master create secret generic toggle-master-secrets \
           --from-env-file=secrets.local.env
         rm secrets.local.env

    2. Abrir a UI do Argo CD:
         ${module.argocd.port_forward_command}

    3. Descobrir o DNS do Load Balancer:
         kubectl -n toggle-master get ingress toggle-master-api
  EOT
}
