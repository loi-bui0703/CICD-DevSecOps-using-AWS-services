#!/usr/bin/env bash
set -euo pipefail

: "${SONAR_HOST:?SONAR_HOST is required}"
: "${SONAR_TOKEN:?SONAR_TOKEN is required}"

SCAN_DIR="${SCAN_DIR:-target-repo}"
SONAR_PROJECT_KEY="${SONAR_PROJECT_KEY:-devsecops-factory}"
SCAN_REPORT_DIR="${SCAN_REPORT_DIR:-$(pwd)/scan-reports}"
RAW_SAST_DIR="${SCAN_REPORT_DIR}/raw/sast"
ISSUES_REPORT="${RAW_SAST_DIR}/sonar-issues.json"
LEGACY_ISSUES_REPORT="${SCAN_REPORT_DIR}/sonar-issues.json"
TOOL_BASE_DIR="${WORKSPACE:-$(pwd)}/security/sast"
SCANNER_VERSION="${SONAR_SCANNER_VERSION:-5.0.1.3006}"
SCANNER_HOME="${TOOL_BASE_DIR}/sonar-scanner"
NODE_VERSION="${NODE_VERSION:-v22.11.0}"
NODE_HOME="${TOOL_BASE_DIR}/nodejs"

echo "============================================================"
echo "  SAST SCAN - SonarQube"
echo "  Sonar host  : ${SONAR_HOST}"
echo "  Project key : ${SONAR_PROJECT_KEY}"
echo "  Scan target : ${SCAN_DIR}"
echo "  Report file : ${ISSUES_REPORT}"
echo "============================================================"

mkdir -p "${RAW_SAST_DIR}" "${TOOL_BASE_DIR}"

if command -v sonar-scanner >/dev/null 2>&1; then
  SCANNER_BIN="$(command -v sonar-scanner)"
else
  SCANNER_BIN="${SCANNER_HOME}/bin/sonar-scanner"
  if [ ! -x "${SCANNER_BIN}" ]; then
    echo "[*] Sonar Scanner not found. Installing..."
    curl -sSLo /tmp/sonar-scanner.zip "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SCANNER_VERSION}.zip"
    unzip -o -q /tmp/sonar-scanner.zip -d "${TOOL_BASE_DIR}"
    rm -rf "${SCANNER_HOME}"
    mv "${TOOL_BASE_DIR}/sonar-scanner-${SCANNER_VERSION}" "${SCANNER_HOME}"
    chmod +x "${SCANNER_BIN}"
  fi
fi

if ! command -v node >/dev/null 2>&1; then
  ARCH="$(uname -m)"
  case "${ARCH}" in
    x86_64|amd64) NODE_ARCH="linux-x64" ;;
    aarch64|arm64) NODE_ARCH="linux-arm64" ;;
    *) echo "[!] Unsupported architecture for Node.js install: ${ARCH}"; exit 1 ;;
  esac

  echo "[*] Node.js not found. Installing ${NODE_VERSION} for ${NODE_ARCH}..."
  mkdir -p "${NODE_HOME}"
  curl -sSLo /tmp/nodejs.tar.gz "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-${NODE_ARCH}.tar.gz"
  tar -xzf /tmp/nodejs.tar.gz -C "${NODE_HOME}" --strip-components=1
  export PATH="${NODE_HOME}/bin:${PATH}"
fi

node -v

if [ ! -d "${SCAN_DIR}" ]; then
  echo "[!] Scan target not found: ${SCAN_DIR}"
  exit 1
fi

pushd "${SCAN_DIR}" >/dev/null
rm -rf .scannerwork

"${SCANNER_BIN}" \
  -Dsonar.projectKey="${SONAR_PROJECT_KEY}" \
  -Dsonar.sources="." \
  -Dsonar.exclusions="**/node_modules/**,**/dist/**,**/build/**,**/.git/**" \
  -Dsonar.host.url="${SONAR_HOST}" \
  -Dsonar.login="${SONAR_TOKEN}" \
  -Dsonar.projectVersion="${IMAGE_TAG:-latest}" \
  -Dsonar.scm.disabled=true \
  "$@"

popd >/dev/null

echo "[*] Exporting SonarQube issues JSON..."
if curl -fsS -u "${SONAR_TOKEN}:" \
  "${SONAR_HOST}/api/issues/search?componentKeys=${SONAR_PROJECT_KEY}&resolved=false&ps=500" \
  -o "${ISSUES_REPORT}"; then
  cp "${ISSUES_REPORT}" "${LEGACY_ISSUES_REPORT}" 2>/dev/null || true
else
  printf '{"issues":[],"warning":"Could not export SonarQube issues from API"}\n' > "${ISSUES_REPORT}"
  cp "${ISSUES_REPORT}" "${LEGACY_ISSUES_REPORT}" 2>/dev/null || true
fi

echo "[+] SAST scan completed."
