variable "cluster_name" {
  description = "Base name for the ECS cluster (environment suffix is appended automatically)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name used as a prefix in resource names and tags"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where ECS tasks and their security group will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs to place Fargate tasks in"
  type        = list(string)
}

variable "task_cpu" {
  description = "CPU units for the Fargate task (256 = 0.25 vCPU — smallest available)"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Memory in MiB for the Fargate task (512 is the minimum for 256 CPU)"
  type        = string
  default     = "512"
}
