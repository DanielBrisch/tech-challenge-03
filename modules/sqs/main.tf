
locals {
  tags = merge(var.tags, { Project = var.project })
  name = "${var.project}-evaluations"
}

resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq ? 1 : 0

  name                      = "${local.name}-dlq"
  message_retention_seconds = var.dlq_retention_seconds

  tags = merge(local.tags, { Name = "${local.name}-dlq" })
}

resource "aws_sqs_queue" "this" {
  name = local.name

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds

  receive_wait_time_seconds = 20

  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : null

  tags = merge(local.tags, { Name = local.name })
}
