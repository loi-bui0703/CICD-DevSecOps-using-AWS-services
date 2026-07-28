#!/usr/bin/env bash
set -euo pipefail

SCAN_DIR="${SCAN_DIR:-${1:-.}}"
SCAN_REPORT_DIR="${SCAN_REPORT_DIR:-$(pwd)/scan-reports}"
RAW_SCA_DIR="${SCAN_REPORT_DIR}/raw/sca"
JSON_REPORT="${RAW_SCA_DIR}/trivy-sca-report.json"
HTML_REPORT="${RAW_SCA_DIR}/trivy-sca-report.html"
LEGACY_JSON_REPORT="${SCAN_REPORT_DIR}/trivy-sca-report.json"
LEGACY_HTML_REPORT="${SCAN_REPORT_DIR}/trivy-sca-report.html"

echo "============================================================"
echo "  SCA SCAN - Trivy filesystem"
echo "  Scan target : ${SCAN_DIR}"
echo "  Report dir  : ${RAW_SCA_DIR}"
echo "============================================================"

mkdir -p "${RAW_SCA_DIR}"

if ! command -v trivy >/dev/null 2>&1; then
  echo "[*] Trivy not found. Installing..."
  TOOL_BIN_DIR="${WORKSPACE:-$(pwd)}/.tools/bin"
  mkdir -p "${TOOL_BIN_DIR}"
  curl -sfL "https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh" \
    | sh -s -- -b "${TOOL_BIN_DIR}"
  export PATH="${TOOL_BIN_DIR}:${PATH}"
fi

echo "[*] Vulnerability summary:"
trivy fs \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --quiet \
  "${SCAN_DIR}"

echo "[*] Generating JSON report..."
trivy fs \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --format json \
  --output "${JSON_REPORT}" \
  "${SCAN_DIR}"

echo "[*] Generating HTML report..."
if trivy fs \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --template "@contrib/html.tpl" \
  --output "${HTML_REPORT}" \
  "${SCAN_DIR}"; then
  cp "${HTML_REPORT}" "${LEGACY_HTML_REPORT}" 2>/dev/null || true
else
  echo "[!] HTML report generation skipped. JSON report is still available."
fi

cp "${JSON_REPORT}" "${LEGACY_JSON_REPORT}" 2>/dev/null || true

if [ "${SECURITY_MODE:-report-only}" = "enforce" ]; then
  BLOCKING_COUNT="$(
    jq --arg severities ",${SECURITY_BLOCK_SEVERITIES:-CRITICAL}," \
      '[.Results[]?.Vulnerabilities[]? |
        select(.Severity as $severity |
          $severities | contains("," + $severity + ",")
        )] | length' \
      "${JSON_REPORT}"
  )"
  if [ "${BLOCKING_COUNT}" -gt 0 ]; then
    echo "[!] SCA gate blocked ${BLOCKING_COUNT} finding(s) with severity ${SECURITY_BLOCK_SEVERITIES:-CRITICAL}."
    exit 1
  fi
fi

echo "[+] SCA scan completed."
