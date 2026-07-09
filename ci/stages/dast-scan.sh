#!/bin/bash

# ============================================================
# DAST SCAN — OWASP ZAP (Full Scan Mode)
# ============================================================

echo "============================================================"
echo "  DAST SCAN — OWASP ZAP"
echo "  Target URL Container: staging-app-local"
echo "  Report Directory    : ${REPORT_DIR}"
echo "============================================================"
if [ -z "$REPORT_DIR" ]; then
    REPORT_DIR="$(pwd)/scan-reports"
fi
mkdir -p "$REPORT_DIR"
chmod -R 777 "$REPORT_DIR"

echo "[*] Ensuring staging-app-local container is running..."
docker ps -a --filter "name=staging-app-local"

TARGET_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' staging-app-local 2>/dev/null)

if [ -z "$TARGET_IP" ]; then
    docker logs staging-app-local || echo "Could not retrieve logs for staging-app-local. Container might not be running."
    exit 1
fi
TARGET_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' staging-app-local)

if [ -z "$TARGET_IP" ]; then
    echo "[!] Error: Could not determine IP address of staging-app-local container. Is it running and healthy?"
    exit 1
fi

TARGET_URL="http://${TARGET_IP}:3000"
echo "[*] Target App IP detected: $TARGET_IP"
echo "[*] ZAP will scan: $TARGET_URL"

docker run --rm \
    --user root \
    -v "$REPORT_DIR:/zap/wrk:rw" \
    ghcr.io/zaproxy/zaproxy:stable \
    zap-full-scan.py \
    -t "$TARGET_URL" \
    -r zap-report.html \
    -x zap-report.xml \
    -J zap-report.json \
    -m 2 \
    -T 5

if [ -f "$REPORT_DIR/zap-report.html" ]; then
    echo "[+] DAST Scan completed! Report is located at: $REPORT_DIR/zap-report.html"
   chmod -R 777 "$REPORT_DIR"
else
    echo "[!] Error: ZAP finished but no report file found!"
    exit 1
fi