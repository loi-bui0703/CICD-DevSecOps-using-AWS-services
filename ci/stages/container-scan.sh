#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE_FULL_PATH:?IMAGE_FULL_PATH is required}"

SCAN_REPORT_DIR="${SCAN_REPORT_DIR:-$(pwd)/scan-reports}"
RAW_CONTAINER_DIR="${SCAN_REPORT_DIR}/raw/container"
JSON_REPORT="${RAW_CONTAINER_DIR}/trivy-container-report.json"
LEGACY_JSON_REPORT="${SCAN_REPORT_DIR}/container-scan-report.json"

echo "============================================================"
echo "  CONTAINER SCAN - Trivy image"
echo "  Image       : ${IMAGE_FULL_PATH}"
echo "  Report file : ${JSON_REPORT}"
echo "============================================================"

mkdir -p "${RAW_CONTAINER_DIR}"

if ! command -v trivy >/dev/null 2>&1; then
  echo "[*] Trivy not found. Installing..."
  curl -sfL "https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh" | sh -s -- -b /usr/local/bin
fi

trivy image \
  --severity HIGH,CRITICAL \
  --format json \
  --output "${JSON_REPORT}" \
  "${IMAGE_FULL_PATH}"

cp "${JSON_REPORT}" "${LEGACY_JSON_REPORT}" 2>/dev/null || true

trivy image \
  --severity HIGH,CRITICAL \
  --format table \
  "${IMAGE_FULL_PATH}"

echo "[+] Container scan completed."
