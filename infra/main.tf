
locals {
  cluster_name = "${var.project}-eks"

  services = [
    "auth-service",
    "flag-service",
    "targeting-service",
    "evaluation-service",
    "analytics-service",
  ]

  databases = {
    auth      = "auth_db"
    flags     = "flags_db"
    targeting = "targeting_db"
  }
}

data "aws_iam_role" "lab" {
  name = var.lab_role_name
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "random_password" "master_key" {
  length  = 32
  special = false
}

module "networking" {
  source = "../modules/networking"

  project            = var.project
  cluster_name       = local.cluster_name
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
}

module "eks" {
  source = "../modules/eks"

  project      = var.project
  cluster_name = local.cluster_name
  lab_role_arn = data.aws_iam_role.lab.arn

  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids

  cluster_version     = var.cluster_version
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
}

module "rds" {
  source   = "../modules/rds"
  for_each = local.databases

  project  = var.project
  name     = each.key
  db_name  = each.value
  password = random_password.db.result

  vpc_id              = module.networking.vpc_id
  subnet_ids          = module.networking.private_subnet_ids
  allowed_cidr_blocks = [module.networking.vpc_cidr]

  instance_class    = var.db_instance_class
  storage_encrypted = var.db_storage_encrypted
}

module "elasticache" {
  source = "../modules/elasticache"

  project             = var.project
  vpc_id              = module.networking.vpc_id
  subnet_ids          = module.networking.private_subnet_ids
  allowed_cidr_blocks = [module.networking.vpc_cidr]
  node_type           = var.redis_node_type
}

module "dynamodb" {
  source = "../modules/dynamodb"

  project    = var.project
  table_name = var.dynamodb_table_name
}

module "sqs" {
  source  = "../modules/sqs"
  project = var.project
}

module "ecr" {
  source = "../modules/ecr"

  project  = var.project
  services = local.services
}
