terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Generate random string for unique S3 bucket name
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# =============================================================================
# AWS-01: AWS Budget & IAM Setup
# =============================================================================

# AWS Budget setup to prevent cost overrun
resource "aws_budgets_budget" "monthly_budget" {
  name              = "${var.project_name}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.budget_limit_amount
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }
}

# IAM Role for ECS Task Execution (for pulling ECR images and logging)
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task (to allow task permissions at runtime)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# =============================================================================
# AWS-02: Amazon ECR Setup
# =============================================================================

resource "aws_ecr_repository" "tetris" {
  name                 = "devsecops/tetris"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-ecr"
    Environment = "shared"
  }
}

# =============================================================================
# AWS-04: Amazon S3 Bucket Setup for Security Reports
# =============================================================================

resource "aws_s3_bucket" "security_reports" {
  bucket        = "devsecops-reports-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-reports-bucket"
    Environment = "security"
  }
}

# Enable S3 Versioning
resource "aws_s3_bucket_versioning" "reports_versioning" {
  bucket = aws_s3_bucket.security_reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable S3 Server-Side Encryption (SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "reports_encryption" {
  bucket = aws_s3_bucket.security_reports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access for security reports
resource "aws_s3_bucket_public_access_block" "reports_public_block" {
  bucket = aws_s3_bucket.security_reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Policy: Auto-delete files after 30 days
resource "aws_s3_bucket_lifecycle_configuration" "reports_lifecycle" {
  bucket = aws_s3_bucket.security_reports.id

  rule {
    id     = "delete-after-30-days"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

# Create report folder structures in S3 using empty objects
resource "aws_s3_object" "prefix_secrets" {
  bucket       = aws_s3_bucket.security_reports.id
  key          = "reports/secrets/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "prefix_sca" {
  bucket       = aws_s3_bucket.security_reports.id
  key          = "reports/sca/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "prefix_sast" {
  bucket       = aws_s3_bucket.security_reports.id
  key          = "reports/sast/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "prefix_container" {
  bucket       = aws_s3_bucket.security_reports.id
  key          = "reports/container/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "prefix_dast" {
  bucket       = aws_s3_bucket.security_reports.id
  key          = "reports/dast/"
  content_type = "application/x-directory"
}

# =============================================================================
# Networking (VPC, Subnets, Routing, and Security Groups)
# =============================================================================

# Fetch available Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Standard VPC definition
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway for public access
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets (2 zones for High Availability)
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-2"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# CloudWatch Log Group for ECS logs
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

# =============================================================================
# Security Groups
# =============================================================================

# ALB Staging Security Group
resource "aws_security_group" "alb_staging" {
  name        = "${var.project_name}-alb-staging-sg"
  description = "Allow inbound HTTP to staging ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB Production Security Group
resource "aws_security_group" "alb_production" {
  name        = "${var.project_name}-alb-prod-sg"
  description = "Allow inbound HTTP to production ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Fargate Tasks Security Group
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Allow inbound traffic from ALBs only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Traffic from staging ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_staging.id]
  }

  ingress {
    description     = "Traffic from production ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_production.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Needed to pull image from ECR
  }
}

# =============================================================================
# AWS-03: Amazon ECS Fargate Cluster & Service Setup
# =============================================================================

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled" # Bật CloudWatch Container Insights (OBS-01)
  }
}

# Fargate Capacity Provider for ECS Cluster
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT" # FARGATE_SPOT reduces cost by up to 70%
    weight            = 100
  }
}

# Application Load Balancer - Staging
resource "aws_lb" "staging" {
  name               = "${var.project_name}-alb-staging"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_staging.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Environment = var.environment_staging
  }
}

resource "aws_lb_target_group" "staging" {
  name        = "${var.project_name}-tg-staging"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    port                = var.container_port
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "staging" {
  load_balancer_arn = aws_lb.staging.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.staging.arn
  }
}

# Application Load Balancer - Production
resource "aws_lb" "production" {
  name               = "${var.project_name}-alb-prod"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_production.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Environment = var.environment_production
  }
}

resource "aws_lb_target_group" "production" {
  name        = "${var.project_name}-tg-prod"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    port                = var.container_port
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "production" {
  load_balancer_arn = aws_lb.production.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.production.arn
  }
}

# ECS Task Definition (Shared for staging/production but can be customized)
resource "aws_ecs_task_definition" "tetris" {
  family                   = "tetris-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "tetris"
      image     = "${aws_ecr_repository.tetris.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "tetris"
        }
      }
    }
  ])
}

# ECS Service - Staging
resource "aws_ecs_service" "staging" {
  name            = "tetris-staging"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.tetris.arn
  desired_count   = 1

  # Run on FARGATE_SPOT to minimize cost
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true # Assign public IP to access ECR and pull base images
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.staging.arn
    container_name   = "tetris"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.staging]
}

# ECS Service - Production
resource "aws_ecs_service" "production" {
  name            = "tetris-production"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.tetris.arn
  desired_count   = 2 # 2 replicas for HA on Production

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.production.arn
    container_name   = "tetris"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.production]
}
