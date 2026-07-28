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

output "jenkins_ci_policy_arn" {
  description = "IAM policy to attach to the Jenkins user or role."
  value       = aws_iam_policy.jenkins_ci.arn
}

output "jenkins_ci_user_name" {
  description = "Dedicated local Jenkins IAM user when create_local_jenkins_user is enabled."
  value       = try(aws_iam_user.jenkins_ci[0].name, null)
}

output "ecs_task_family" {
  description = "Task definition family consumed by the Jenkins ECS deployment stages."
  value       = aws_ecs_task_definition.tetris.family
}

output "securityhub_importer_function_name" {
  description = "Lambda function name when the optional Security Hub importer is enabled."
  value       = try(aws_lambda_function.securityhub_importer[0].function_name, null)
}
