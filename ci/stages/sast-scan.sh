#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  SAST SCAN — SonarQube"
echo "  SonarQube host : ${SONAR_HOST}"
echo "  Project key    : devsecops-factory"
echo "============================================================"

TOOL_BASE_DIR="${WORKSPACE}/security/sast"
TOOL_HOME="${TOOL_BASE_DIR}/sonar-scanner"
mkdir -p "${TOOL_BASE_DIR}"

# 1. --- CÀI ĐẶT SONAR SCANNER ---
if [ ! -f "${TOOL_HOME}/bin/sonar-scanner" ]; then
    echo "[*] Sonar Scanner not found. Downloading..."
    curl -sSLo /tmp/sonar-scanner.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006.zip
    unzip -o -q /tmp/sonar-scanner.zip -d "${TOOL_BASE_DIR}/"
    mv "${TOOL_BASE_DIR}/sonar-scanner-5.0.1.3006" "${TOOL_HOME}"
fi
chmod +x "${TOOL_HOME}/bin/sonar-scanner"

# 2. --- ÉP CÀI ĐẶT LẠI NODE.JS LÊN V22 CHO JENKINS ---
NODE_VERSION="v22.11.0"
NODE_DIR="${TOOL_BASE_DIR}/nodejs"

echo "[*] Clearing old Node.js cache and installing Node.js ${NODE_VERSION}..."
# Xóa thẳng tay thư mục cũ để ép tải bản mới
rm -rf "${NODE_DIR}"
mkdir -p "${NODE_DIR}"

curl -sSLo /tmp/nodejs.tar.gz "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-arm64.tar.gz"
tar -xzf /tmp/nodejs.tar.gz -C "${NODE_DIR}" --strip-components=1

export PATH="${NODE_DIR}/bin:$PATH"

echo "[*] Node.js version:"
node -v

# 3. --- CHUẨN BỊ QUÉT ---
echo "[*] Running scan..."

SCAN_TARGET="target-repo"
if [ -d "$SCAN_TARGET" ]; then
    echo "[*] Navigating into $SCAN_TARGET"
    # Di chuyển hẳn vào thư mục code để tránh lỗi path của bridge JS
    cd "$SCAN_TARGET"
else
    echo "[!] target-repo not found, scanning current directory."
fi

echo "[*] Current directory is $(pwd)"

# 4. --- CHẠY SCANNER TỪ BÊN TRONG THƯ MỤC CODE ---
rm -rf .scannerwork/

"${TOOL_HOME}/bin/sonar-scanner" \
  -Dsonar.projectKey="devsecops-factory" \
  -Dsonar.sources="app/src" \
  -Dsonar.exclusions="**/node_modules/**,**/dist/**,**/build/**,**/.git/**" \
  -Dsonar.host.url="${SONAR_HOST}" \
  -Dsonar.login="${SONAR_TOKEN}" \
  -Dsonar.projectVersion="${IMAGE_TAG:-latest}" \
  -Dsonar.scm.disabled=true