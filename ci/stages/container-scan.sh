#!/usr/bin/env bash
set -euo pipefail

echo "[*] Checking for Trivy installation..."

if ! command -v trivy &> /dev/null; then
    echo "[!] Trivy not found. Installing Trivy..."
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
fi

echo "[*] Starting scan for image: ${IMAGE_FULL_PATH}"

echo "[*] Displaying vulnerabilities (Pipeline will fail if HIGH/CRITICAL are found)..."
trivy image \
  --severity HIGH,CRITICAL \
  --format table \
  "${IMAGE_FULL_PATH}"