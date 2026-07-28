#!/usr/bin/env bash
set -euo pipefail

if [ "${CONFIRM_AWS_CLEANUP:-}" != "devsecops-factory" ]; then
  echo "Refusing cleanup. Set CONFIRM_AWS_CLEANUP=devsecops-factory after reviewing the Terraform plan." >&2
  exit 2
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWS_PROFILE="${AWS_PROFILE:-${AWS_PROFILE_NAME:-devsecops-factory}}"
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
EXPECTED_AWS_ACCOUNT_ID="${EXPECTED_AWS_ACCOUNT_ID:-}"
ECS_CLUSTER="${ECS_CLUSTER:-devsecops-factory-cluster}"
ECS_TASK_FAMILY="${ECS_TASK_FAMILY:-tetris-app}"

export AWS_PROFILE AWS_REGION

actual_account_id="$(aws sts get-caller-identity --query Account --output text)"
if [ -n "${EXPECTED_AWS_ACCOUNT_ID}" ] && [ "${actual_account_id}" != "${EXPECTED_AWS_ACCOUNT_ID}" ]; then
  echo "Refusing cleanup: AWS account ${actual_account_id} does not match EXPECTED_AWS_ACCOUNT_ID=${EXPECTED_AWS_ACCOUNT_ID}." >&2
  exit 3
fi

echo "AWS cleanup account: ${actual_account_id}"
echo "AWS profile/region: ${AWS_PROFILE}/${AWS_REGION}"

cluster_status="$(
  aws ecs describe-clusters \
    --clusters "${ECS_CLUSTER}" \
    --query 'clusters[0].status' \
    --output text 2>/dev/null || true
)"

if [ "${cluster_status}" = "ACTIVE" ]; then
  "${PROJECT_ROOT}/scripts/scale-ecs.sh" down
else
  echo "ECS cluster ${ECS_CLUSTER} is not active; skipping scale-down."
fi

if [ "${DESTROY_TERRAFORM:-false}" = "true" ]; then
  terraform -chdir="${PROJECT_ROOT}/infrastructure/terraform" destroy

  task_definitions="$(
    aws ecs list-task-definitions \
      --family-prefix "${ECS_TASK_FAMILY}" \
      --status ACTIVE \
      --query 'taskDefinitionArns' \
      --output text
  )"
  for task_definition in ${task_definitions}; do
    if [ "${task_definition}" != "None" ]; then
      aws ecs deregister-task-definition \
        --task-definition "${task_definition}" \
        --output json >/dev/null
    fi
  done

  state_count="$(
    terraform -chdir="${PROJECT_ROOT}/infrastructure/terraform" state list |
      wc -l |
      tr -d '[:space:]'
  )"
  if [ "${state_count}" != "0" ]; then
    echo "Cleanup is incomplete: Terraform state still contains ${state_count} entries." >&2
    exit 4
  fi

  echo "Terraform state is empty and active ${ECS_TASK_FAMILY} task definitions are deregistered."
else
  echo "ECS tasks are stopped. ALBs and other provisioned resources can still incur charges."
  echo "Set DESTROY_TERRAFORM=true and rerun to review and approve terraform destroy."
fi
