#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
ECS_CLUSTER="${ECS_CLUSTER:-devsecops-factory-cluster}"
STAGING_COUNT="${STAGING_COUNT:-1}"
PRODUCTION_COUNT="${PRODUCTION_COUNT:-2}"

case "${ACTION}" in
  up)
    ;;
  down)
    STAGING_COUNT=0
    PRODUCTION_COUNT=0
    ;;
  *)
    echo "Usage: $0 up|down" >&2
    exit 2
    ;;
esac

aws ecs update-service \
  --region "${AWS_REGION}" \
  --cluster "${ECS_CLUSTER}" \
  --service tetris-staging \
  --desired-count "${STAGING_COUNT}" \
  --output json >/dev/null

aws ecs update-service \
  --region "${AWS_REGION}" \
  --cluster "${ECS_CLUSTER}" \
  --service tetris-production \
  --desired-count "${PRODUCTION_COUNT}" \
  --output json >/dev/null

echo "ECS desired counts updated: staging=${STAGING_COUNT}, production=${PRODUCTION_COUNT}"
