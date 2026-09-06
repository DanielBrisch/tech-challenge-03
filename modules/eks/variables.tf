variable "project" {
  description = "Prefixo dos nomes dos recursos."
  type        = string
}

variable "cluster_name" {
  description = "Nome do cluster EKS."
  type        = string
}

variable "cluster_version" {
  description = <<-EOT
    Versão do Kubernetes. Confira as versões em suporte padrão com:
      aws eks describe-cluster-versions --query 'clusterVersions[].clusterVersion'
  EOT
  type        = string
  default     = "1.34"
}

variable "lab_role_arn" {
  description = "ARN da LabRole (AWS Academy) usada pelo control plane e pelos nós."
  type        = string
}

variable "vpc_id" {
  description = "VPC onde o cluster será criado."
  type        = string
}

variable "private_subnet_ids" {
  description = "Subnets privadas onde os nós rodam."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Subnets públicas, para os Load Balancers do Ingress."
  type        = list(string)
}

variable "node_instance_types" {
  description = "Tipos de instância do node group. O Academy costuma limitar até t3.medium."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND ou SPOT."
  type        = string
  default     = "ON_DEMAND"
}

variable "node_desired_size" {
  description = "Número desejado de nós."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Número mínimo de nós."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Número máximo de nós."
  type        = number
  default     = 4
}

variable "node_disk_size" {
  description = "Tamanho do disco de cada nó, em GB."
  type        = number
  default     = 20
}

variable "enable_metrics_server" {
  description = "Instalar o add-on Metrics Server (pré-requisito do HPA)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos."
  type        = map(string)
  default     = {}
}
