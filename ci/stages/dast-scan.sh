#!/usr/bin/env bash
set -euo pipefail

: "${TARGET_URL:?TARGET_URL is required}"

SCAN_REPORT_DIR="${SCAN_REPORT_DIR:-$(pwd)/scan-reports}"
REPORT_DIR="${REPORT_DIR:-${SCAN_REPORT_DIR}/raw/dast}"
JSON_REPORT="${REPORT_DIR}/zap-report.json"
HTML_REPORT="${REPORT_DIR}/zap-report.html"
XML_REPORT="${REPORT_DIR}/zap-report.xml"
ZAP_DATA_CONTAINER="zap-data-${BUILD_NUMBER:-$$}"

cleanup() {
  docker rm -f "${ZAP_DATA_CONTAINER}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "============================================================"
echo "  DAST SCAN - OWASP ZAP baseline"
echo "  Target URL : ${TARGET_URL}"
echo "  Report dir : ${REPORT_DIR}"
echo "============================================================"

mkdir -p "$REPORT_DIR"
cleanup
docker create -v /zap/wrk --name "${ZAP_DATA_CONTAINER}" alpine:latest /bin/true >/dev/null

docker run --rm \
  --user root \
  --add-host=host.docker.internal:host-gateway \
  --network "${DOCKER_NETWORK:-devsecops}" \
  --volumes-from "${ZAP_DATA_CONTAINER}" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py \
  -t "$TARGET_URL" \
  -r zap-report.html \
  -x zap-report.xml \
  -J zap-report.json \
  -m 2 \
  -T 10 || ZAP_EXIT=$?

ZAP_EXIT="${ZAP_EXIT:-0}"
docker cp "${ZAP_DATA_CONTAINER}:/zap/wrk/." "${REPORT_DIR}/"

if [ "$ZAP_EXIT" -ge 3 ]; then
  echo "[!] ZAP runtime error"
  exit "$ZAP_EXIT"
fi

mkdir -p "${SCAN_REPORT_DIR}"
cp "${JSON_REPORT}" "${SCAN_REPORT_DIR}/zap-report.json" 2>/dev/null || true
cp "${HTML_REPORT}" "${SCAN_REPORT_DIR}/zap-report.html" 2>/dev/null || true
cp "${XML_REPORT}" "${SCAN_REPORT_DIR}/zap-report.xml" 2>/dev/null || true

if [ "$ZAP_EXIT" -ge 1 ] && [ "${DAST_FAIL_ON_ALERT:-false}" = "true" ]; then
  echo "[!] ZAP found alerts and DAST_FAIL_ON_ALERT=true"
  exit "$ZAP_EXIT"
fi

echo "[+] DAST completed. Reports saved to $REPORT_DIR"
exit 0
