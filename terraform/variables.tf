variable "project_name" {
  description = "Name of the project — used as a prefix on all resource names and tags"
  type        = string
  default     = "aws-infra-profile"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy all resources into"
  type        = string
  default     = "ap-southeast-2" # Sydney
}
