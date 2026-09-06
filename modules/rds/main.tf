
locals {
  tags = merge(var.tags, { Project = var.project })
  name = "${var.project}-${var.name}"
}

resource "aws_db_subnet_group" "this" {
  name       = local.name
  subnet_ids = var.subnet_ids
  tags       = merge(local.tags, { Name = local.name })
}

resource "aws_security_group" "this" {
  name        = "${local.name}-rds"
  description = "Acesso PostgreSQL ao ${local.name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL a partir da VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-rds" })
}

resource "aws_db_instance" "this" {
  identifier = local.name

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = var.storage_encrypted

  db_name  = var.db_name
  username = var.username
  password = var.password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = false
  backup_retention_period = var.backup_retention_period
  apply_immediately       = true

  auto_minor_version_upgrade = true

  tags = merge(local.tags, { Name = local.name })
}
