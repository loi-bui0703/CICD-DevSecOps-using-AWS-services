#!/bin/bash
echo "============================================================"
echo "  IaC SCAN — Checkov"
echo "============================================================"

docker rm -f checkov-data 2>/dev/null || true

echo "[*] Creating temporary storage container..."
docker create -v /tf --name checkov-data alpine:latest /bin/true

echo "[*] Copying target repository..."
docker cp ./target-repo checkov-data:/tf/

echo "[*] Running Checkov Scan (Console Output)..."
docker run --rm \
    --volumes-from checkov-data \
    bridgecrew/checkov:latest \
    --directory /tf/target-repo \
    --soft-fail \
    --quiet

echo "[*] Generating JSON report..."
docker run --rm \
    --volumes-from checkov-data \
    bridgecrew/checkov:latest \
    --directory /tf/target-repo \
    --soft-fail \
    --output json > checkov_report.json

echo "[*] Cleaning up temporary resources..."
docker rm -v checkov-data >/dev/null

if [ -s checkov_report.json ]; then
    echo "============================================================"
    echo "[+] IaC Scan completed successfully."
    grep -E "passed|failed|resource_count" checkov_report.json | head -n 5
    echo "============================================================"
else
    echo "[!] Error: Report file was not generated."
    exit 1
fi