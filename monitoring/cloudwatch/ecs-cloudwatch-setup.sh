#!/bin/bash
# =============================================================================
# ecs-cloudwatch-setup.sh — Member 5 (Observability & QA)
# Script to enable CloudWatch Container Insights & create Log Groups / Alarms
# =============================================================================

AWS_REGION="${AWS_REGION:-ap-southeast-1}"
CLUSTER_NAME="${CLUSTER_NAME:-devsecops-factory}"
STAGING_SERVICE="${STAGING_SERVICE:-tetris-staging}"
PROD_SERVICE="${PROD_SERVICE:-tetris-production}"

echo "=== 1. Enabling Container Insights on ECS Cluster: ${CLUSTER_NAME} ==="
aws ecs update-cluster-settings \
  --cluster "${CLUSTER_NAME}" \
  --settings name=containerInsights,value=enabled \
  --region "${AWS_REGION}"

echo "=== 2. Creating Log Group for ECS Applications ==="
aws logs create-log-group --log-group-name "/ecs/${CLUSTER_NAME}/tetris-app" --region "${AWS_REGION}" 2>/dev/null || echo "Log Group already exists."
aws logs put-retention-policy --log-group-name "/ecs/${CLUSTER_NAME}/tetris-app" --retention-in-days 14 --region "${AWS_REGION}"

echo "=== 3. Creating CloudWatch High CPU Alarm for Staging ==="
aws cloudwatch put-metric-alarm \
  --alarm-name "ECS-Staging-High-CPU" \
  --alarm-description "Triggers when Staging CPU utilization exceeds 80% for 5 minutes" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=ClusterName,Value="${CLUSTER_NAME}" Name=ServiceName,Value="${STAGING_SERVICE}" \
  --unit Percent \
  --region "${AWS_REGION}"

echo "=== 4. Creating CloudWatch High Memory Alarm for Production ==="
aws cloudwatch put-metric-alarm \
  --alarm-name "ECS-Prod-High-Memory" \
  --alarm-description "Triggers when Production Memory utilization exceeds 85% for 5 minutes" \
  --metric-name MemoryUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 85 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=ClusterName,Value="${CLUSTER_NAME}" Name=ServiceName,Value="${PROD_SERVICE}" \
  --unit Percent \
  --region "${AWS_REGION}"

echo "=== CloudWatch Setup Complete! ==="
