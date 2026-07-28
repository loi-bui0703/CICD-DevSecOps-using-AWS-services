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
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

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
  name         = "${var.project_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.budget_limit_amount
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
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
  force_delete         = true

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

    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
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

resource "aws_s3_object" "prefix_iac" {
  bucket       = aws_s3_bucket.security_reports.id
  key          = "reports/iac/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "prefix_asff" {
  bucket       = aws_s3_bucket.security_reports.id
  key          = "reports/asff/"
  content_type = "application/x-directory"
}

# =============================================================================
# AWS-05: Optional Lambda importer for AWS Security Hub
# =============================================================================

resource "aws_securityhub_account" "main" {
  count = var.enable_security_hub_importer ? 1 : 0
}

data "archive_file" "securityhub_importer" {
  count       = var.enable_security_hub_importer ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/../lambda/securityhub-importer/lambda_function.py"
  output_path = "${path.module}/.terraform/securityhub-importer.zip"
}

resource "aws_iam_role" "securityhub_importer" {
  count = var.enable_security_hub_importer ? 1 : 0
  name  = "${var.project_name}-securityhub-importer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "securityhub_importer" {
  count = var.enable_security_hub_importer ? 1 : 0
  name  = "${var.project_name}-securityhub-importer"
  role  = aws_iam_role.securityhub_importer[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadSecurityReports"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.security_reports.arn}/*"
      },
      {
        Sid      = "ImportSecurityHubFindings"
        Effect   = "Allow"
        Action   = ["securityhub:BatchImportFindings"]
        Resource = "*"
      },
      {
        Sid    = "WriteLambdaLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.securityhub_importer[0].arn}:*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "securityhub_importer" {
  count             = var.enable_security_hub_importer ? 1 : 0
  name              = "/aws/lambda/${var.project_name}-securityhub-importer"
  retention_in_days = 7
}

resource "aws_lambda_function" "securityhub_importer" {
  count            = var.enable_security_hub_importer ? 1 : 0
  function_name    = "${var.project_name}-securityhub-importer"
  role             = aws_iam_role.securityhub_importer[0].arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.securityhub_importer[0].output_path
  source_code_hash = data.archive_file.securityhub_importer[0].output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      SECURITYHUB_REGION = var.aws_region
      ASFF_SUFFIX        = "securityhub-asff.json"
    }
  }

  depends_on = [
    aws_iam_role_policy.securityhub_importer,
    aws_cloudwatch_log_group.securityhub_importer,
    aws_securityhub_account.main
  ]
}

resource "aws_lambda_permission" "allow_s3" {
  count          = var.enable_security_hub_importer ? 1 : 0
  statement_id   = "AllowExecutionFromS3"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.securityhub_importer[0].function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.security_reports.arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_notification" "securityhub_importer" {
  bucket = aws_s3_bucket.security_reports.id

  dynamic "lambda_function" {
    for_each = var.enable_security_hub_importer ? [1] : []
    content {
      lambda_function_arn = aws_lambda_function.securityhub_importer[0].arn
      events              = ["s3:ObjectCreated:*"]
      filter_prefix       = "reports/asff/"
      filter_suffix       = "securityhub-asff.json"
    }
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# Attach this least-privilege policy to the Jenkins IAM principal used by CI.
resource "aws_iam_policy" "jenkins_ci" {
  name        = "${var.project_name}-jenkins-ci"
  description = "Push ECR images, update ECS services, and upload security reports."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrLogin"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "EcrPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = aws_ecr_repository.tetris.arn
      },
      {
        Sid    = "EcsDeploy"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassEcsRoles"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      },
      {
        Sid      = "UploadReports"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.security_reports.arn}/reports/*"
      }
    ]
  })
}

resource "aws_iam_user" "jenkins_ci" {
  count = var.create_local_jenkins_user ? 1 : 0

  name          = "${var.project_name}-jenkins-ci"
  force_destroy = true

  tags = {
    Purpose = "Local Jenkins CI/CD"
  }
}

resource "aws_iam_user_policy_attachment" "jenkins_ci" {
  count = var.create_local_jenkins_user ? 1 : 0

  user       = aws_iam_user.jenkins_ci[0].name
  policy_arn = aws_iam_policy.jenkins_ci.arn
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
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
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
      name                   = "volume-permissions"
      image                  = "${aws_ecr_repository.tetris.repository_url}:latest"
      essential              = false
      user                   = "0"
      readonlyRootFilesystem = true
      command = [
        "sh",
        "-c",
        "chown -R 101:101 /var/cache/nginx /tmp"
      ]
      mountPoints = [
        {
          sourceVolume  = "nginx-cache"
          containerPath = "/var/cache/nginx"
          readOnly      = false
        },
        {
          sourceVolume  = "nginx-tmp"
          containerPath = "/tmp"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "volume-permissions"
        }
      }
    },
    {
      name                   = "tetris"
      image                  = "${aws_ecr_repository.tetris.repository_url}:latest"
      essential              = true
      user                   = "101"
      readonlyRootFilesystem = true
      dependsOn = [
        {
          containerName = "volume-permissions"
          condition     = "SUCCESS"
        }
      ]
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ]
      healthCheck = {
        command = [
          "CMD-SHELL",
          "wget -q -O /dev/null http://localhost:${var.container_port}/ || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
      mountPoints = [
        {
          sourceVolume  = "nginx-cache"
          containerPath = "/var/cache/nginx"
          readOnly      = false
        },
        {
          sourceVolume  = "nginx-tmp"
          containerPath = "/tmp"
          readOnly      = false
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

  volume {
    name = "nginx-cache"
  }

  volume {
    name = "nginx-tmp"
  }
}

# ECS Service - Staging
resource "aws_ecs_service" "staging" {
  name            = "tetris-staging"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.tetris.arn
  desired_count   = var.staging_desired_count

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

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  depends_on = [aws_lb_listener.staging]
}

# ECS Service - Production
resource "aws_ecs_service" "production" {
  name            = "tetris-production"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.tetris.arn
  desired_count   = var.production_desired_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
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

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  depends_on = [aws_lb_listener.production]
}
