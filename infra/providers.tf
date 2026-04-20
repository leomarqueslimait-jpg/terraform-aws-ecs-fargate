terraform {
  required_version = "~> 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-ecs-fargate-state"
    key            = "ecs/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-ecs-fargate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "random" {
  
}