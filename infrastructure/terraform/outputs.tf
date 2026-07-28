output "ecr_repository_url" {
  description = "The URL of the Amazon ECR repository"
  value       = aws_ecr_repository.tetris.repository_url
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket for security reports"
  value       = aws_s3_bucket.security_reports.id
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "alb_dns_staging" {
  description = "DNS name of the staging ALB"
  value       = aws_lb.staging.dns_name
}

output "alb_dns_production" {
  description = "DNS name of the production ALB"
  value       = aws_lb.production.dns_name
}

output "budget_name" {
  description = "The name of the AWS budget"
  value       = aws_budgets_budget.monthly_budget.name
}
