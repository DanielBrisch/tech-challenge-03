
resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key

  attribute {
    name = var.hash_key
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  tags = merge(var.tags, {
    Project = var.project
    Name    = var.table_name
  })
}
