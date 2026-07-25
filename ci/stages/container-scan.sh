#!/usr/bin/env bash
# ============================================================
# CONTAINER SCAN — Trivy (Image Mode)
#
# Environment variables (set by Jenkinsfile stage 9):
#   IMAGE_FULL_PATH   — full image URI, e.g. localhost:5001/devsecops/tetris:abc123
#   SCAN_REPORT_DIR   — directory to write reports into
# ============================================================
set -euo pipefail

echo "============================================================"
echo "  CONTAINER SCAN — Trivy"
echo "  Image       : ${IMAGE_FULL_PATH}"
echo "  Report Dir  : ${SCAN_REPORT_DIR}"
echo "============================================================"

if ! command -v trivy &> /dev/null; then
    echo "[*] Trivy not found. Installing..."
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
fi

mkdir -p "${SCAN_REPORT_DIR}"

# Console output for Jenkins log readability
echo "[*] Vulnerability summary (HIGH, CRITICAL):"
trivy image \
    --severity HIGH,CRITICAL \
    --format table \
    "${IMAGE_FULL_PATH}"

# JSON report — required by Jenkinsfile expectedReports check
echo "[*] Generating JSON report..."
trivy image \
    --severity HIGH,CRITICAL \
    --format json \
    --output "${SCAN_REPORT_DIR}/container-scan-report.json" \
    "${IMAGE_FULL_PATH}"

echo "============================================================"
echo "[+] Container scan completed. Report: ${SCAN_REPORT_DIR}/container-scan-report.json"
echo "============================================================"