#!/usr/bin/env bash
# ============================================================
# DAST SCAN — OWASP ZAP (Full Scan Mode)
#
# Environment variables (set by Jenkinsfile stage 14):
#   TARGET_URL   — full URL to scan, e.g. http://staging.example.com
#   REPORT_DIR   — directory to write ZAP reports into
# ============================================================
set -euo pipefail

echo "============================================================"
echo "  DAST SCAN — OWASP ZAP"
echo "  Target URL  : ${TARGET_URL}"
echo "  Report Dir  : ${REPORT_DIR}"
echo "============================================================"

if [ -z "${TARGET_URL:-}" ]; then
    echo "[!] Error: TARGET_URL is not set. Set STAGING_URL in Jenkins pipeline parameters."
    exit 1
fi

mkdir -p "${REPORT_DIR}"

echo "[*] Running ZAP full scan against ${TARGET_URL} ..."
docker run --rm \
    --user root \
    --network devsecops \
    -v "${REPORT_DIR}:/zap/wrk:rw" \
    ghcr.io/zaproxy/zaproxy:stable \
    zap-full-scan.py \
    -t "${TARGET_URL}" \
    -r zap-report.html \
    -x zap-report.xml \
    -J zap-report.json \
    -m 2 \
    -T 5

if [ -f "${REPORT_DIR}/zap-report.html" ]; then
    echo "[+] DAST Scan completed. Reports in: ${REPORT_DIR}"
else
    echo "[!] Error: ZAP finished but no report was generated."
    exit 1
fi