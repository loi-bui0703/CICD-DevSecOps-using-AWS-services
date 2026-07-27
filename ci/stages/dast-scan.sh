#!/usr/bin/env bash
set -euo pipefail

: "${TARGET_URL:?TARGET_URL is required}"

REPORT_DIR="${REPORT_DIR:-$(pwd)/scan-reports/raw/dast}"
SCAN_REPORT_DIR="${SCAN_REPORT_DIR:-$(pwd)/scan-reports}"
JSON_REPORT="${REPORT_DIR}/zap-report.json"
HTML_REPORT="${REPORT_DIR}/zap-report.html"
XML_REPORT="${REPORT_DIR}/zap-report.xml"

echo "============================================================"
echo "  DAST SCAN - OWASP ZAP baseline"
echo "  Target URL : ${TARGET_URL}"
echo "  Report dir : ${REPORT_DIR}"
echo "============================================================"

mkdir -p "$REPORT_DIR"
chmod -R 777 "$REPORT_DIR"

docker run --rm \
  --user root \
  --add-host=host.docker.internal:host-gateway \
  -v "$REPORT_DIR:/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py \
  -t "$TARGET_URL" \
  -r zap-report.html \
  -x zap-report.xml \
  -J zap-report.json \
  -m 2 \
  -T 10 || ZAP_EXIT=$?

ZAP_EXIT="${ZAP_EXIT:-0}"

if [ "$ZAP_EXIT" = "3" ]; then
  echo "[!] ZAP runtime error"
  exit 3
fi

mkdir -p "${SCAN_REPORT_DIR}"
cp "${JSON_REPORT}" "${SCAN_REPORT_DIR}/zap-report.json" 2>/dev/null || true
cp "${HTML_REPORT}" "${SCAN_REPORT_DIR}/zap-report.html" 2>/dev/null || true
cp "${XML_REPORT}" "${SCAN_REPORT_DIR}/zap-report.xml" 2>/dev/null || true

if [ "$ZAP_EXIT" = "1" ] && [ "${DAST_FAIL_ON_ALERT:-false}" = "true" ]; then
  echo "[!] ZAP found fail-level alerts and DAST_FAIL_ON_ALERT=true"
  exit 1
fi

echo "[+] DAST completed. Reports saved to $REPORT_DIR"
exit 0
