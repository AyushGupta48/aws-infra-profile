# Resolve the current region at plan time — used in the CloudWatch log config
data "aws_region" "current" {}

# CloudWatch log group for nginx container output
# 7-day retention keeps costs within free-tier limits
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-${var.environment}-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM role that ECS assumes to pull container images and write logs on our behalf
resource "aws_iam_role" "ecs_execution" {
  name = "${var.project_name}-${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach the AWS-managed policy that covers ECR pulls and CloudWatch log writes
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS cluster — the logical boundary that groups all tasks and services
resource "aws_ecs_cluster" "main" {
  name = "${var.cluster_name}-${var.environment}"

  # Container Insights costs extra — disabled to stay free-tier friendly
  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name        = "${var.cluster_name}-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Task definition — the blueprint Fargate uses to launch the container
# Specifies the image, resource allocation, networking mode, and log destination
resource "aws_ecs_task_definition" "nginx" {
  family                   = "${var.project_name}-${var.environment}-nginx"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" # Fargate requires awsvpc — each task gets its own ENI
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "nginx:latest" # Public Docker Hub image — no ECR needed
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "nginx"
        }
      }
    }
  ])

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Security group — firewall rules attached directly to each Fargate task's ENI
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-${var.environment}-ecs-sg"
  description = "Allow inbound HTTP and all outbound for ECS tasks"
  vpc_id      = var.vpc_id

  # Accept HTTP traffic from the public internet
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound so tasks can pull images from Docker Hub
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ECS service — keeps exactly 1 Fargate task running at all times
resource "aws_ecs_service" "nginx" {
  name            = "${var.project_name}-${var.environment}-nginx-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true # Tasks need a public IP to reach Docker Hub from a public subnet
  }

  # Prevent Terraform from rolling back deployments triggered outside of Terraform (e.g. CI/CD)
  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
