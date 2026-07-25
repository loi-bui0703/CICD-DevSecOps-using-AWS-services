#!/usr/bin/env bash
# ============================================================
# IaC SCAN — Checkov (mono-repo mode)
#
# Environment variables (set by Jenkinsfile stage 7):
#   SCAN_DIR        — root of the repository (= WORKSPACE)
#   SCAN_REPORT_DIR — directory to write the JSON report into
# ============================================================
set -euo pipefail

echo "============================================================"
echo "  IaC SCAN — Checkov"
echo "  Scan target : ${SCAN_DIR}"
echo "  Report Dir  : ${SCAN_REPORT_DIR}"
echo "============================================================"

mkdir -p "${SCAN_REPORT_DIR}"

# Console summary (soft-fail so pipeline stages control pass/fail)
echo "[*] Running Checkov scan (console output)..."
docker run --rm \
    -v "${SCAN_DIR}:/tf:ro" \
    bridgecrew/checkov:latest \
    --directory /tf \
    --soft-fail \
    --quiet

# JSON report — required by Jenkinsfile expectedReports and S3 upload
echo "[*] Generating JSON report..."
docker run --rm \
    -v "${SCAN_DIR}:/tf:ro" \
    bridgecrew/checkov:latest \
    --directory /tf \
    --soft-fail \
    --output json \
    > "${SCAN_REPORT_DIR}/checkov_report.json"

if [ -s "${SCAN_REPORT_DIR}/checkov_report.json" ]; then
    echo "============================================================"
    echo "[+] IaC scan completed."
    grep -E '"passed"|"failed"|"resource_count"' \
        "${SCAN_REPORT_DIR}/checkov_report.json" | head -n 5 || true
    echo "============================================================"
else
    echo "[!] Error: Checkov report was not generated."
    exit 1
fi