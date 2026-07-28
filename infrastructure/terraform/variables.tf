variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "devsecops-factory"
}

variable "environment_staging" {
  description = "Staging environment name"
  type        = string
  default     = "staging"
}

variable "environment_production" {
  description = "Production environment name"
  type        = string
  default     = "production"
}

variable "budget_limit_amount" {
  description = "AWS monthly budget limit in USD"
  type        = string
  default     = "50.0"
}

variable "budget_notification_email" {
  description = "Email address to receive budget alerts"
  type        = string
  default     = "your-email@example.com"
}

variable "container_port" {
  description = "Container port of the application"
  type        = number
  default     = 8080
}
