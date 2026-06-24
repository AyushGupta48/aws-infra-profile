terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS provider targeting the Sydney region
provider "aws" {
  region = var.aws_region
}

# VPC module — creates the core network layer for all resources
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  project_name         = var.project_name
  environment          = var.environment
}

# ECS module — runs an nginx container on Fargate inside the VPC created above
module "ecs" {
  source = "./modules/ecs"

  cluster_name      = var.project_name
  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  task_cpu          = "256"
  task_memory       = "512"
}
