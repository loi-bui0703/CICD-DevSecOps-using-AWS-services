#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
EVIDENCE_DIR="${REPO_ROOT}/results/task-2/evidence"
SUMMARY_FILE="${EVIDENCE_DIR}/static-validation.txt"

mkdir -p "${EVIDENCE_DIR}"
cd "${REPO_ROOT}"

: > "${SUMMARY_FILE}"

record_pass() {
  printf 'PASS | %s\n' "$1" | tee -a "${SUMMARY_FILE}"
}

record_fail() {
  printf 'FAIL | %s\n' "$1" | tee -a "${SUMMARY_FILE}"
  return 1
}

run_check() {
  local name="$1"
  shift
  if "$@" >> "${SUMMARY_FILE}" 2>&1; then
    record_pass "${name}"
  else
    record_fail "${name}"
  fi
}

printf 'Task 2 static handover validation\n' >> "${SUMMARY_FILE}"
printf 'Generated: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "${SUMMARY_FILE}"
printf 'Branch: %s\n\n' "$(git branch --show-current)" >> "${SUMMARY_FILE}"

run_check "git diff has no whitespace errors" git diff --check
run_check "docker-compose.infra.yml renders" \
  docker compose -f docker-compose.infra.yml config --quiet

for script in ci/stages/*.sh; do
  run_check "bash syntax: ${script}" bash -n "${script}"
done

run_check "staging Argo Application has expected repo/path/namespace" \
  bash -c '
    grep -q "repoURL: https://github.com/loi-bui0703/FCAJ-final-project.git" cd/apps/staging.yaml &&
    grep -q "path: kubernetes/overlays/staging" cd/apps/staging.yaml &&
    grep -q "namespace: staging" cd/apps/staging.yaml
  '

run_check "production Argo Application has expected path/namespace" \
  bash -c '
    grep -q "path: kubernetes/overlays/production" cd/apps/production.yaml &&
    grep -q "namespace: production" cd/apps/production.yaml
  '

run_check "Jenkins archives security artifacts" \
  grep -q "artifacts: 'scan-reports/\\*\\*/\\*'" ci/Jenkinsfile
run_check "Jenkins uses commit SHA image tag" \
  grep -q 'env.IMAGE_TAG = env.GIT_COMMIT_SHORT' ci/Jenkinsfile
run_check "Jenkins has production input gate" \
  grep -q 'Object result = input(approval)' ci/Jenkinsfile
run_check "production requires security enforce" \
  grep -q "Production promotion requires SECURITY_MODE=enforce." ci/Jenkinsfile
run_check "ECR login does not enable shell tracing" \
  bash -c '
    grep -q "aws ecr get-login-password" ci/Jenkinsfile &&
    grep -q "set +x" ci/Jenkinsfile
  '

kubectl kustomize kubernetes/overlays/staging \
  > "${EVIDENCE_DIR}/kustomize-staging-rendered.yaml"
record_pass "kustomize staging renders"

kubectl kustomize kubernetes/overlays/production \
  > "${EVIDENCE_DIR}/kustomize-production-rendered.yaml"
record_pass "kustomize production renders"

run_check "staging render uses namespace staging and one replica" \
  bash -c '
    grep -q "namespace: staging" results/task-2/evidence/kustomize-staging-rendered.yaml &&
    grep -q "replicas: 1" results/task-2/evidence/kustomize-staging-rendered.yaml
  '

run_check "production render uses namespace production and three replicas" \
  bash -c '
    grep -q "namespace: production" results/task-2/evidence/kustomize-production-rendered.yaml &&
    grep -q "replicas: 3" results/task-2/evidence/kustomize-production-rendered.yaml
  '

SECRET_SCAN_FILE="${EVIDENCE_DIR}/credential-secret-scan.txt"
{
  printf 'Task 2 obvious-secret pattern scan\n'
  printf 'Generated: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'Scope: ci/Jenkinsfile ci/jenkins-casc.yaml ci/jenkins.env.example '
  printf 'docker-compose.infra.yml cd/apps\n\n'
} > "${SECRET_SCAN_FILE}"

if rg -n \
  -e 'AKIA[0-9A-Z]{16}' \
  -e 'gh[pousr]_[A-Za-z0-9]{20,}' \
  -e '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----' \
  ci/Jenkinsfile ci/jenkins-casc.yaml ci/jenkins.env.example \
  docker-compose.infra.yml cd/apps >> "${SECRET_SCAN_FILE}" 2>&1; then
  printf 'FAIL: possible hardcoded secret pattern found.\n' \
    | tee -a "${SECRET_SCAN_FILE}" "${SUMMARY_FILE}"
  exit 1
else
  printf 'PASS: no AWS access key, GitHub token, or private-key pattern found.\n' \
    | tee -a "${SECRET_SCAN_FILE}"
  record_pass "no obvious hardcoded secret pattern in Task 2 files"
fi

printf '\nSUMMARY: all static Task 2 handover checks passed.\n' \
  | tee -a "${SUMMARY_FILE}"
