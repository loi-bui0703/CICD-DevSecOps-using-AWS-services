#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" != "--yes" ]; then
  echo "Usage: $0 --yes" >&2
  echo "This scales the staging and production ECS services to zero. It does not destroy Terraform resources." >&2
  exit 2
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "${PROJECT_ROOT}/.env" ]; then
  set -a
  source "${PROJECT_ROOT}/.env"
  set +a
fi
unset AWS_PROFILE

AWS_REGION="${AWS_REGION:-ap-southeast-1}"
ECS_CLUSTER="${ECS_CLUSTER:-devsecops-factory-cluster}"
STAGING_SERVICE="${ECS_STAGING_SERVICE:-tetris-staging}"
PRODUCTION_SERVICE="${ECS_PRODUCTION_SERVICE:-tetris-production}"

for command_name in aws jq; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Required command not found: ${command_name}" >&2
    exit 2
  fi
done

IDENTITY="$(
  aws sts get-caller-identity \
    --region "${AWS_REGION}" \
    --output json
)"

echo "Resetting demo services in AWS account $(jq -r '.Account' <<< "${IDENTITY}")..."

for service_name in "${STAGING_SERVICE}" "${PRODUCTION_SERVICE}"; do
  aws ecs update-service \
    --region "${AWS_REGION}" \
    --cluster "${ECS_CLUSTER}" \
    --service "${service_name}" \
    --desired-count 0 \
    --output json >/dev/null
done

aws ecs wait services-stable \
  --region "${AWS_REGION}" \
  --cluster "${ECS_CLUSTER}" \
  --services "${STAGING_SERVICE}" "${PRODUCTION_SERVICE}"

aws ecs describe-services \
  --region "${AWS_REGION}" \
  --cluster "${ECS_CLUSTER}" \
  --services "${STAGING_SERVICE}" "${PRODUCTION_SERVICE}" \
  --query 'services[].{service:serviceName,desired:desiredCount,running:runningCount,pending:pendingCount}' \
  --output table

echo "Demo reset complete. ALBs and other Terraform resources are still provisioned."
