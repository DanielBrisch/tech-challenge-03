output "namespace" {
  description = "Namespace onde o Argo CD foi instalado."
  value       = helm_release.argocd.namespace
}

output "chart_version" {
  description = "Versão do chart instalada."
  value       = helm_release.argocd.version
}

output "admin_password_command" {
  description = "Comando para recuperar a senha inicial do usuário admin."
  value       = "kubectl -n ${helm_release.argocd.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "port_forward_command" {
  description = "Comando para abrir a UI do Argo CD em http://localhost:8080."
  value       = "kubectl -n ${helm_release.argocd.namespace} port-forward svc/argocd-server 8080:80"
}
