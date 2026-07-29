# =============================================================================
# ecs-cloudwatch-setup.ps1 — Member 5 (Observability & QA)
# PowerShell script to enable CloudWatch Container Insights & create Log Groups / Alarms
# =============================================================================

$AWS_REGION = if ($env:AWS_REGION) { $env:AWS_REGION } else { "ap-southeast-1" }
$CLUSTER_NAME = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "devsecops-factory" }
$STAGING_SERVICE = if ($env:STAGING_SERVICE) { $env:STAGING_SERVICE } else { "tetris-staging" }
$PROD_SERVICE = if ($env:PROD_SERVICE) { $env:PROD_SERVICE } else { "tetris-production" }

Write-Host "=== 1. Enabling Container Insights on ECS Cluster: $CLUSTER_NAME ===" -ForegroundColor Cyan
aws ecs update-cluster-settings `
  --cluster $CLUSTER_NAME `
  --settings name=containerInsights,value=enabled `
  --region $AWS_REGION

Write-Host "=== 2. Creating Log Group for ECS Applications ===" -ForegroundColor Cyan
try {
    aws logs create-log-group --log-group-name "/ecs/$CLUSTER_NAME/tetris-app" --region $AWS_REGION
} catch {
    Write-Host "Log Group already exists or created." -ForegroundColor Yellow
}
aws logs put-retention-policy --log-group-name "/ecs/$CLUSTER_NAME/tetris-app" --retention-in-days 14 --region $AWS_REGION

Write-Host "=== 3. Creating CloudWatch High CPU Alarm for Staging ===" -ForegroundColor Cyan
aws cloudwatch put-metric-alarm `
  --alarm-name "ECS-Staging-High-CPU" `
  --alarm-description "Triggers when Staging CPU utilization exceeds 80% for 5 minutes" `
  --metric-name CPUUtilization `
  --namespace AWS/ECS `
  --statistic Average `
  --period 300 `
  --threshold 80 `
  --comparison-operator GreaterThanThreshold `
  --evaluation-periods 1 `
  --dimensions Name=ClusterName,Value=$CLUSTER_NAME Name=ServiceName,Value=$STAGING_SERVICE `
  --unit Percent `
  --region $AWS_REGION

Write-Host "=== 4. Creating CloudWatch High Memory Alarm for Production ===" -ForegroundColor Cyan
aws cloudwatch put-metric-alarm `
  --alarm-name "ECS-Prod-High-Memory" `
  --alarm-description "Triggers when Production Memory utilization exceeds 85% for 5 minutes" `
  --metric-name MemoryUtilization `
  --namespace AWS/ECS `
  --statistic Average `
  --period 300 `
  --threshold 85 `
  --comparison-operator GreaterThanThreshold `
  --evaluation-periods 1 `
  --dimensions Name=ClusterName,Value=$CLUSTER_NAME Name=ServiceName,Value=$PROD_SERVICE `
  --unit Percent `
  --region $AWS_REGION

Write-Host "=== CloudWatch Setup Complete! ===" -ForegroundColor Green
