#!/usr/bin/env bash
set -euo pipefail

REQUESTED_SCAN_DIR="${SCAN_DIR:-${1:-}}"
if [ -n "${REQUESTED_SCAN_DIR}" ] && [ "${REQUESTED_SCAN_DIR}" != "." ]; then
  SCAN_DIR="${REQUESTED_SCAN_DIR}"
elif [ -d "target-repo" ]; then
  SCAN_DIR="target-repo"
else
  SCAN_DIR="."
fi

SCAN_REPORT_DIR="${SCAN_REPORT_DIR:-$(pwd)/scan-reports}"
RAW_IAC_DIR="${SCAN_REPORT_DIR}/raw/iac"
JSON_REPORT="${RAW_IAC_DIR}/checkov-report.json"
LEGACY_JSON_REPORT="checkov_report.json"
CHECKOV_DATA_CONTAINER="checkov-data-${BUILD_NUMBER:-$$}"

cleanup() {
  docker rm -f "${CHECKOV_DATA_CONTAINER}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "============================================================"
echo "  IaC SCAN - Checkov"
echo "  Scan target : ${SCAN_DIR}"
echo "  Report file : ${JSON_REPORT}"
echo "============================================================"

mkdir -p "${RAW_IAC_DIR}"
cleanup

echo "[*] Creating temporary scan volume..."
docker create -v /tf --name "${CHECKOV_DATA_CONTAINER}" alpine:latest /bin/true >/dev/null

echo "[*] Copying scan target into temporary volume..."
docker cp "${SCAN_DIR}" "${CHECKOV_DATA_CONTAINER}:/tf/scan-target"

echo "[*] Running Checkov summary..."
docker run --rm \
  --volumes-from "${CHECKOV_DATA_CONTAINER}" \
  bridgecrew/checkov:latest \
  --directory /tf/scan-target \
  --soft-fail \
  --quiet

echo "[*] Generating JSON report..."
docker run --rm \
  --volumes-from "${CHECKOV_DATA_CONTAINER}" \
  bridgecrew/checkov:latest \
  --directory /tf/scan-target \
  --soft-fail \
  --output json > "${JSON_REPORT}"

cp "${JSON_REPORT}" "${LEGACY_JSON_REPORT}" 2>/dev/null || true

if [ ! -s "${JSON_REPORT}" ]; then
  echo "[!] Checkov report was not generated."
  exit 1
fi

echo "[+] IaC scan completed."
