locals {
  common_tags = {
    Project   = "terraform-aws-ecs-fargate"
    ManagedBy = "Terraform"

  }
}

module "networking" {
  source = "./modules/networking"

  vpc_cidr              = "10.1.0.0/16"
  name                  = "Terraform-aws-ecs-fargate"
  public_subnets_cidr   = ["10.1.1.0/24", "10.1.2.0/24"]   #10.1.0.0/24 to 10.1.15.0/24
  private_subnets_cidr  = ["10.1.16.0/24", "10.1.17.0/24"] #10.1.16.0/24 - 10.1.31.0/24
  isolated_subnets_cidr = ["10.1.32.0/24", "10.1.33.0/24"] #10.1.32.0/24 - 10.1.47.0/24
  #spare subnet block = 10.1.48.0/24 + (for future tiers)
  azs  = ["us-east-1a", "us-east-1b"]
  tags = local.common_tags
}

module "ecr" {
  source = "./modules/ecr"

  name      = "ecs-fargate-app"
  region    = "us-east-1"
  image_tag = "v1"
  app_path  = "${path.module}/../app"
  tags      = local.common_tags
}

module "secrets" {
  source = "./modules/secrets"

  name = "ecs-fargate-db-password"
  recovery_window_in_days = 0 # changeb to 30 for production
  tags = local.common_tags
}

module "rds" {
  source = "./modules/rds"

  isolated_subnets_id = module.networking.isolated_subnets_id
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  db_name             = "appdb"
  db_username         = "dbadmin"
  db_password = module.secrets.db_password
  db_sg_group_id      = module.networking.rds_sg_id
  tags                = local.common_tags

}

module "alb" {
  source = "./modules/alb"

  alb_sg_ids         = module.networking.alb_sg_id
  public_subnets_ids = module.networking.public_subnets_id
  vpc_id             = module.networking.vpc_id
  tags               = local.common_tags

}

module "ecs" {
  source = "./modules/ecs"

  private_subnets_id = module.networking.private_subnets_id
  ecs_sg_id          = module.networking.ecs_sg_id
  target_group_arn   = module.alb.target_group_arn
  depends_on         = [module.ecr]
  container_image    = "${module.ecr.repository_url}:v1"
  secrets_arn        = module.secrets.rds_secret_arn
  db_endpoint        = module.rds.db_endpoint
  tags               = local.common_tags
}