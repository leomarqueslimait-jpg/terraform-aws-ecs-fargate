module "networking" {
    source = "./modules/networking"

    vpc_cidr = "10.1.0.0/16"
    name = "Terraform-aws-ecs-fargate"
    public_subnets_cidr = ["10.1.1.0/24", "10.1.2.0/24"]#10.1.0.0/24 to 10.1.15.0/24
    private_subnets_cidr = ["10.1.16.0/24", "10.1.17.0/24"]#10.1.16.0/24 - 10.1.31.0/24
    isolated_subnets_cidr = ["10.1.32.0/24", "10.1.33.0/24"]#10.1.32.0/24 - 10.1.47.0/24
    #spare subnet block = 10.1.48.0/24 + (for future tiers)
    azs = ["us-east-1a", "us-east-1b"]
}

