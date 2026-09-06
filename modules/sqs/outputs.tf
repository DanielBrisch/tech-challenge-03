output "queue_url" {
  description = "URL da fila. Vai para o Secret do Kubernetes como AWS_SQS_URL."
  value       = aws_sqs_queue.this.url
}

output "queue_arn" {
  description = "ARN da fila."
  value       = aws_sqs_queue.this.arn
}

output "dlq_url" {
  description = "URL da dead-letter queue, se habilitada."
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].url : null
}
