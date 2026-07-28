#!/usr/bin/env bash
set -euo pipefail

SCAN_DIR="${SCAN_DIR:-${1:-.}}"
SCAN_REPORT_DIR="${SCAN_REPORT_DIR:-$(pwd)/scan-reports}"
RAW_SECRETS_DIR="${SCAN_REPORT_DIR}/raw/secrets"
REPORT_FILE="${RAW_SECRETS_DIR}/gitleaks-report.json"
LEGACY_REPORT_FILE="${SCAN_REPORT_DIR}/gitleaks-report.json"

echo "============================================================"
echo "  SECRETS SCAN - Gitleaks"
echo "  Scan target : ${SCAN_DIR}"
echo "  Report file : ${REPORT_FILE}"
echo "============================================================"

mkdir -p "${RAW_SECRETS_DIR}"

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "[*] Gitleaks not found. Installing..."
  curl -sSL "https://github.com/gitleaks/gitleaks/releases/download/v8.18.2/gitleaks_8.18.2_linux_x64.tar.gz" | tar -xz
  chmod +x gitleaks
  export PATH="${PATH}:$(pwd)"
fi

set +e
gitleaks detect \
  --source "${SCAN_DIR}" \
  --report-path "${REPORT_FILE}" \
  --report-format json \
  --no-banner
GITLEAKS_EXIT=$?
set -e

cp "${REPORT_FILE}" "${LEGACY_REPORT_FILE}" 2>/dev/null || true

if [ "${GITLEAKS_EXIT}" -eq 1 ]; then
  echo "[!] Secrets detected by Gitleaks. Check ${REPORT_FILE}"
  exit 1
fi

if [ "${GITLEAKS_EXIT}" -ne 0 ]; then
  echo "[!] Gitleaks runtime error. Exit code: ${GITLEAKS_EXIT}"
  exit "${GITLEAKS_EXIT}"
fi

echo "[+] Secrets scan completed. No secrets found."
