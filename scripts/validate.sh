#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

cd "${PROJECT_ROOT}"

echo "[1/7] Validate shell syntax"
for script in ci/stages/*.sh scripts/*.sh; do
  bash -n "${script}"
done

echo "[2/7] Test security report normalization and ASFF generation"
python3 -m unittest discover -s ci/stages/tests -p 'test_*.py'
python3 -m py_compile \
  ci/stages/normalize-reports.py \
  ci/stages/generate-asff.py \
  infrastructure/lambda/securityhub-importer/lambda_function.py

echo "[3/7] Render Kubernetes overlays"
kubectl kustomize kubernetes/overlays/staging > "${TEMP_DIR}/staging.yaml"
kubectl kustomize kubernetes/overlays/production > "${TEMP_DIR}/production.yaml"
grep -q "namespace: staging" "${TEMP_DIR}/staging.yaml"
grep -q "namespace: production" "${TEMP_DIR}/production.yaml"
grep -q "kind: Deployment" "${TEMP_DIR}/staging.yaml"
grep -q "kind: Ingress" "${TEMP_DIR}/production.yaml"

echo "[4/7] Validate Docker Compose models"
docker compose -f docker-compose.infra.yml config --quiet
docker compose -f docker-compose.security.yml config --quiet
docker compose -f docker-compose.obs.yml config --quiet
docker compose config --quiet

echo "[5/7] Validate JSON and monitoring configuration"
jq empty ecs-task-def.json
jq empty monitoring/grafana/dashboards/service-availability.json

echo "[6/7] Validate Terraform formatting"
terraform -chdir=infrastructure/terraform fmt -check -recursive
if [ -d infrastructure/terraform/.terraform/providers ]; then
  terraform -chdir=infrastructure/terraform validate
else
  echo "[*] Terraform providers are not initialized; run terraform init -backend=false before validate."
fi

echo "[7/7] Optional application build"
if [ "${FULL_BUILD:-false}" = "true" ]; then
  npm --prefix app ci
  npm --prefix app run build
else
  echo "[*] Skipped npm build. Run FULL_BUILD=true scripts/validate.sh for the complete build."
fi

echo "[+] Static validation completed successfully."
