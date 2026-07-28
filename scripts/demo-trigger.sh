#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infrastructure/terraform"
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JENKINS_JOB="${JENKINS_JOB:-devsecops-factory}"
JENKINS_USER="${JENKINS_USER:-admin}"
AWS_REGION="${AWS_REGION:-ap-southeast-1}"

case "${1:-}" in
  "")
    DRY_RUN=false
    ;;
  --dry-run)
    DRY_RUN=true
    ;;
  *)
    echo "Usage: $0 [--dry-run]" >&2
    exit 2
    ;;
esac

for command_name in curl git jq terraform; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Required command not found: ${command_name}" >&2
    exit 2
  fi
done

if [ ! -f "${PROJECT_ROOT}/.env" ]; then
  echo "Missing ${PROJECT_ROOT}/.env. Jenkins credentials are not available." >&2
  exit 2
fi

cd "${PROJECT_ROOT}"

if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
  echo "The working tree is not clean. Commit local changes before triggering Jenkins." >&2
  echo "Jenkins checks out committed branch content and will not see uncommitted files." >&2
  exit 2
fi

RELEASE_BRANCH="$(git branch --show-current)"
if [ -z "${RELEASE_BRANCH}" ]; then
  echo "Cannot determine the current Git branch." >&2
  exit 2
fi

set -a
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/.env"
set +a

: "${JENKINS_ADMIN_PASS:?JENKINS_ADMIN_PASS is required in .env}"

ECR_REPOSITORY_URI="$(terraform -chdir="${TERRAFORM_DIR}" output -raw ecr_repository_url)"
ECR_REGISTRY="${ECR_REPOSITORY_URI%%/*}"
IMAGE_REPOSITORY="${ECR_REPOSITORY_URI#*/}"
ECS_CLUSTER="$(terraform -chdir="${TERRAFORM_DIR}" output -raw ecs_cluster_name)"
ECS_TASK_FAMILY="$(terraform -chdir="${TERRAFORM_DIR}" output -raw ecs_task_family)"
SECURITY_REPORT_BUCKET="$(terraform -chdir="${TERRAFORM_DIR}" output -raw s3_bucket_name)"
STAGING_DNS="$(terraform -chdir="${TERRAFORM_DIR}" output -raw alb_dns_staging)"

COOKIE_FILE="$(mktemp /tmp/devsecops-demo-cookie.XXXXXX)"
HEADER_FILE="$(mktemp /tmp/devsecops-demo-headers.XXXXXX)"
cleanup() {
  rm -f "${COOKIE_FILE}" "${HEADER_FILE}"
}
trap cleanup EXIT

curl -fsS --retry 15 --retry-delay 2 --retry-connrefused \
  -u "${JENKINS_USER}:${JENKINS_ADMIN_PASS}" \
  -o /dev/null \
  "${JENKINS_URL}/login"

CRUMB_JSON="$(
  curl -fsS \
    -c "${COOKIE_FILE}" \
    -u "${JENKINS_USER}:${JENKINS_ADMIN_PASS}" \
    "${JENKINS_URL}/crumbIssuer/api/json"
)"
CRUMB_FIELD="$(jq -r '.crumbRequestField' <<< "${CRUMB_JSON}")"
CRUMB_VALUE="$(jq -r '.crumb' <<< "${CRUMB_JSON}")"

PARAMETER_API="$(
  curl -g -fsS \
    -u "${JENKINS_USER}:${JENKINS_ADMIN_PASS}" \
    "${JENKINS_URL}/job/${JENKINS_JOB}/api/json?tree=property[parameterDefinitions[name]]"
)"
if ! jq -e \
  '[.property[]?.parameterDefinitions[]?.name] | index("DEMO_PRESET") != null' \
  >/dev/null <<< "${PARAMETER_API}"; then
  echo "Jenkins has not loaded the FULL_AWS_DEMO parameters. Running one safe seed build..."

  PARAMETER_COUNT="$(
    jq '[.property[]?.parameterDefinitions[]?.name] | length' <<< "${PARAMETER_API}"
  )"
  if [ "${PARAMETER_COUNT}" -gt 0 ]; then
    SEED_ENDPOINT="buildWithParameters"
  else
    SEED_ENDPOINT="build"
  fi

  curl -fsS \
    -D "${HEADER_FILE}" \
    -o /dev/null \
    -b "${COOKIE_FILE}" \
    -u "${JENKINS_USER}:${JENKINS_ADMIN_PASS}" \
    -X POST \
    -H "${CRUMB_FIELD}: ${CRUMB_VALUE}" \
    "${JENKINS_URL}/job/${JENKINS_JOB}/${SEED_ENDPOINT}"

  SEED_QUEUE_URL="$(
    awk 'tolower($1) == "location:" {print $2}' "${HEADER_FILE}" \
      | tr -d '\r' \
      | tail -n 1
  )"
  if [ -z "${SEED_QUEUE_URL}" ]; then
    echo "Jenkins did not return a queue URL for the seed build." >&2
    exit 1
  fi

  SEED_BUILD_NUMBER=""
  for _attempt in $(seq 1 120); do
    SEED_QUEUE_JSON="$(
      curl -fsS \
        -u "${JENKINS_USER}:${JENKINS_ADMIN_PASS}" \
        "${SEED_QUEUE_URL}api/json"
    )"
    SEED_BUILD_NUMBER="$(
      jq -r '.executable.number // empty' <<< "${SEED_QUEUE_JSON}"
    )"
    if [ -n "${SEED_BUILD_NUMBER}" ]; then
      break
    fi
    sleep 1
  done
  if [ -z "${SEED_BUILD_NUMBER}" ]; then
    echo "Timed out waiting for the safe seed build to start." >&2
    exit 1
  fi

  for _attempt in $(seq 1 300); do
    SEED_BUILD_JSON="$(
      curl -fsS \
        -u "${JENKINS_USER}:${JENKINS_ADMIN_PASS}" \
        "${JENKINS_URL}/job/${JENKINS_JOB}/${SEED_BUILD_NUMBER}/api/json"
    )"
    if [ "$(jq -r '.building' <<< "${SEED_BUILD_JSON}")" = "false" ]; then
      SEED_RESULT="$(jq -r '.result' <<< "${SEED_BUILD_JSON}")"
      break
    fi
    sleep 1
  done
  if [ "${SEED_RESULT:-}" != "SUCCESS" ]; then
    echo "Safe seed build #${SEED_BUILD_NUMBER} did not succeed: ${SEED_RESULT:-timeout}" >&2
    exit 1
  fi

  PARAMETER_API="$(
    curl -g -fsS \
      -u "${JENKINS_USER}:${JENKINS_ADMIN_PASS}" \
      "${JENKINS_URL}/job/${JENKINS_JOB}/api/json?tree=property[parameterDefinitions[name]]"
  )"
  if ! jq -e \
    '[.property[]?.parameterDefinitions[]?.name] | index("DEMO_PRESET") != null' \
    >/dev/null <<< "${PARAMETER_API}"; then
    echo "Seed build succeeded, but Jenkins still did not load DEMO_PRESET." >&2
    exit 1
  fi
  echo "Safe seed build #${SEED_BUILD_NUMBER} loaded the new parameters."
fi

if [ "${DRY_RUN}" = "true" ]; then
  echo "FULL_AWS_DEMO preflight passed."
  echo "Release branch: ${RELEASE_BRANCH}"
  echo "ECR repository: ${ECR_REPOSITORY_URI}"
  echo "ECS cluster/task family: ${ECS_CLUSTER}/${ECS_TASK_FAMILY}"
  echo "Security report bucket: ${SECURITY_REPORT_BUCKET}"
  echo "Staging URL: http://${STAGING_DNS}"
  echo "No FULL_AWS_DEMO build was triggered."
  exit 0
fi

curl -fsS \
  -D "${HEADER_FILE}" \
  -o /dev/null \
  -b "${COOKIE_FILE}" \
  -u "${JENKINS_USER}:${JENKINS_ADMIN_PASS}" \
  -X POST \
  -H "${CRUMB_FIELD}: ${CRUMB_VALUE}" \
  --data-urlencode 'DEMO_PRESET=FULL_AWS_DEMO' \
  --data-urlencode 'REGISTRY_TARGET=ecr' \
  --data-urlencode 'LOCAL_REGISTRY=local-registry:5000' \
  --data-urlencode "ECR_REGISTRY=${ECR_REGISTRY}" \
  --data-urlencode "IMAGE_REPOSITORY=${IMAGE_REPOSITORY}" \
  --data-urlencode 'IMAGE_PLATFORM=linux/amd64' \
  --data-urlencode "AWS_REGION=${AWS_REGION}" \
  --data-urlencode 'AWS_AUTH_MODE=jenkins-credentials' \
  --data-urlencode 'AWS_CREDENTIALS_ID=aws-credentials' \
  --data-urlencode 'SECURITY_MODE=enforce' \
  --data-urlencode 'SECURITY_BLOCK_SEVERITIES=CRITICAL' \
  --data-urlencode 'ENABLE_SAST=false' \
  --data-urlencode 'ENABLE_DAST=true' \
  --data-urlencode 'DAST_GATE_MODE=report-only' \
  --data-urlencode "STAGING_URL=http://${STAGING_DNS}" \
  --data-urlencode 'ENABLE_S3_UPLOAD=true' \
  --data-urlencode "SECURITY_REPORT_BUCKET=${SECURITY_REPORT_BUCKET}" \
  --data-urlencode 'ENABLE_SECURITY_HUB_IMPORT=false' \
  --data-urlencode 'ENABLE_GITOPS_UPDATE=false' \
  --data-urlencode "RELEASE_BRANCH=${RELEASE_BRANCH}" \
  --data-urlencode 'ENABLE_ECS_DEPLOY=true' \
  --data-urlencode "ECS_CLUSTER=${ECS_CLUSTER}" \
  --data-urlencode 'ECS_STAGING_SERVICE=tetris-staging' \
  --data-urlencode "ECS_STAGING_TASK_FAMILY=${ECS_TASK_FAMILY}" \
  --data-urlencode 'ECS_STAGING_DESIRED_COUNT=1' \
  --data-urlencode 'ECS_PRODUCTION_SERVICE=tetris-production' \
  --data-urlencode "ECS_PRODUCTION_TASK_FAMILY=${ECS_TASK_FAMILY}" \
  --data-urlencode 'ECS_PRODUCTION_DESIRED_COUNT=1' \
  --data-urlencode 'ECS_CONTAINER_NAME=tetris' \
  --data-urlencode 'PROMOTE_PRODUCTION=true' \
  --data-urlencode "PRODUCTION_APPROVERS=${JENKINS_USER}" \
  --data-urlencode 'APPROVAL_TIMEOUT_MINUTES=30' \
  "${JENKINS_URL}/job/${JENKINS_JOB}/buildWithParameters"

QUEUE_URL="$(
  awk 'tolower($1) == "location:" {print $2}' "${HEADER_FILE}" \
    | tr -d '\r' \
    | tail -n 1
)"
if [ -z "${QUEUE_URL}" ]; then
  echo "Jenkins accepted the request but did not return a queue URL." >&2
  exit 1
fi

BUILD_NUMBER=""
for _attempt in $(seq 1 60); do
  QUEUE_JSON="$(
    curl -fsS \
      -u "${JENKINS_USER}:${JENKINS_ADMIN_PASS}" \
      "${QUEUE_URL}api/json"
  )"
  if [ "$(jq -r '.cancelled // false' <<< "${QUEUE_JSON}")" = "true" ]; then
    echo "The queued Jenkins build was cancelled." >&2
    exit 1
  fi
  BUILD_NUMBER="$(jq -r '.executable.number // empty' <<< "${QUEUE_JSON}")"
  if [ -n "${BUILD_NUMBER}" ]; then
    break
  fi
  sleep 1
done

if [ -z "${BUILD_NUMBER}" ]; then
  echo "Timed out waiting for Jenkins to assign a build number." >&2
  exit 1
fi

echo "FULL_AWS_DEMO build #${BUILD_NUMBER} started."
echo "Console: ${JENKINS_URL}/job/${JENKINS_JOB}/${BUILD_NUMBER}/console"
echo "Manual gate: ${JENKINS_URL}/job/${JENKINS_JOB}/${BUILD_NUMBER}/input/"
echo "Image: ${ECR_REGISTRY}/${IMAGE_REPOSITORY}:<commit-sha>"
echo "Staging URL: http://${STAGING_DNS}"
