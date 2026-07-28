#!/usr/bin/env bash
set -euo pipefail

if [ "${CONFIRM_AWS_CLEANUP:-}" != "devsecops-factory" ]; then
  echo "Refusing cleanup. Set CONFIRM_AWS_CLEANUP=devsecops-factory after reviewing the Terraform plan." >&2
  exit 2
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${PROJECT_ROOT}/scripts/scale-ecs.sh" down

if [ "${DESTROY_TERRAFORM:-false}" = "true" ]; then
  terraform -chdir="${PROJECT_ROOT}/infrastructure/terraform" destroy
else
  echo "ECS tasks are stopped. ALBs and other provisioned resources can still incur charges."
  echo "Set DESTROY_TERRAFORM=true and rerun to review and approve terraform destroy."
fi
