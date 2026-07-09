#!/bin/bash
# ============================================================
# SCA SCAN — Trivy (Filesystem Mode)
# ============================================================

echo "============================================================"
echo "  SCA SCAN (Filesystem) — Trivy"
echo "  Scan target : ${SCAN_DIR}"
echo "============================================================"

# 1. Install Trivy if not found
if ! command -v trivy &> /dev/null; then
    echo "[*] Trivy not found. Installing..."
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
fi

# 2. Print Summary to Console (This allows you to see findings in Jenkins Logs)
echo "[*] Vulnerability Summary (HIGH,CRITICAL):"
trivy fs --scanners vuln \
    --severity HIGH,CRITICAL \
    --quiet \
    "${SCAN_DIR}"

# 3. Generate JSON Report for automation
echo "[*] Generating JSON report..."
trivy fs --scanners vuln \
    --severity HIGH,CRITICAL \
    --format json \
    --output "${SCAN_REPORT_DIR}/trivy-sca-report.json" \
    "${SCAN_DIR}"

# 4. Generate HTML Report for human reading
echo "[*] Generating HTML report..."
trivy fs --scanners vuln \
    --severity HIGH,CRITICAL \
    --template "@contrib/html.tpl" \
    --output "${SCAN_REPORT_DIR}/trivy-sca-report.html" \
    "${SCAN_DIR}"

echo "============================================================"
echo "[+] SCA Scan completed."
echo "[+] Reports saved in: ${SCAN_REPORT_DIR}"
echo "============================================================"