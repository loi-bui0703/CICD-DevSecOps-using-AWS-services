#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
EVIDENCE_DIR="${REPO_ROOT}/results/task-2/evidence"
RUNTIME_DIR="/private/tmp/devsecops-task2-evidence"
SOURCE_DIR="${RUNTIME_DIR}/source"
JENKINS_HOME_DIR="${RUNTIME_DIR}/jenkins-home"
JOB_CONFIG="${RUNTIME_DIR}/job-config.xml"
STATE_FILE="${RUNTIME_DIR}/state.env"
COOKIE_JAR="${RUNTIME_DIR}/cookies.txt"

JENKINS_IMAGE="${JENKINS_IMAGE:-devsecops-factory-jenkins:latest}"
JENKINS_CONTAINER="task2-evidence-jenkins"
REGISTRY_CONTAINER="task2-evidence-registry"
JENKINS_URL="http://localhost:18080"
JENKINS_USER="admin"
JENKINS_PASSWORD="task2-local-evidence"
JOB_NAME="task2-handover"

mkdir -p "${EVIDENCE_DIR}/artifacts" "${EVIDENCE_DIR}/screenshots"

container_exists() {
  docker ps -a --format '{{.Names}}' | grep -qx "$1"
}

wait_for_jenkins() {
  local attempt
  for attempt in $(seq 1 180); do
    if curl -fsS "${JENKINS_URL}/login" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "Jenkins did not become ready." >&2
  docker logs "${JENKINS_CONTAINER}" >&2 || true
  return 1
}

refresh_crumb() {
  local crumb_json
  crumb_json="$(curl -fsS -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
    -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" \
    "${JENKINS_URL}/crumbIssuer/api/json")"
  CRUMB_FIELD="$(jq -r '.crumbRequestField' <<< "${crumb_json}")"
  CRUMB_VALUE="$(jq -r '.crumb' <<< "${crumb_json}")"
}

trigger_build() {
  local endpoint="$1"
  shift
  local headers queue_url
  headers="$(mktemp "${RUNTIME_DIR}/headers.XXXXXX")"

  curl -fsS -D "${headers}" -o /dev/null \
    -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
    -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" \
    -H "${CRUMB_FIELD}: ${CRUMB_VALUE}" \
    -X POST \
    "$@" \
    "${JENKINS_URL}/job/${JOB_NAME}/${endpoint}"

  queue_url="$(
    awk 'tolower($1) == "location:" {print $2}' "${headers}" \
      | tr -d '\r' \
      | tail -n 1
  )"
  if [[ -z "${queue_url}" ]]; then
    echo "Jenkins did not return a queue URL." >&2
    return 1
  fi

  while true; do
    local queue_json build_number cancelled
    queue_json="$(curl -fsS -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
      "${queue_url}api/json")"
    build_number="$(jq -r '.executable.number // empty' <<< "${queue_json}")"
    cancelled="$(jq -r '.cancelled // false' <<< "${queue_json}")"
    if [[ "${cancelled}" == "true" ]]; then
      echo "Queued build was cancelled." >&2
      return 1
    fi
    if [[ -n "${build_number}" ]]; then
      printf '%s\n' "${build_number}"
      return 0
    fi
    sleep 1
  done
}

wait_for_build() {
  local build_number="$1"
  while true; do
    local build_json building
    build_json="$(curl -fsS -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
      "${JENKINS_URL}/job/${JOB_NAME}/${build_number}/api/json")"
    building="$(jq -r '.building' <<< "${build_json}")"
    if [[ "${building}" == "false" ]]; then
      jq -r '.result' <<< "${build_json}"
      return 0
    fi
    sleep 3
  done
}

download_console() {
  local build_number="$1"
  local destination="$2"
  curl -fsS -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
    "${JENKINS_URL}/job/${JOB_NAME}/${build_number}/consoleText" \
    > "${destination}"
}

if container_exists "${JENKINS_CONTAINER}" ||
  container_exists "${REGISTRY_CONTAINER}"; then
  echo "Evidence containers already exist. Run cleanup-local-jenkins-evidence.sh first." >&2
  exit 1
fi

rm -rf "${RUNTIME_DIR}"
mkdir -p "${SOURCE_DIR}" "${JENKINS_HOME_DIR}"

rsync -a \
  --exclude '.git' \
  --exclude 'results/task-2/evidence/screenshots/*.png' \
  "${REPO_ROOT}/" "${SOURCE_DIR}/"

git -C "${SOURCE_DIR}" init -b cicd-gitops >/dev/null
git -C "${SOURCE_DIR}" config user.email "task2-evidence@localhost"
git -C "${SOURCE_DIR}" config user.name "Task 2 Evidence"
git -C "${SOURCE_DIR}" add .
git -C "${SOURCE_DIR}" commit -m "test: Task 2 handover snapshot" >/dev/null

SOURCE_COMMIT="$(git -C "${SOURCE_DIR}" rev-parse HEAD)"
SOURCE_SHORT="${SOURCE_COMMIT:0:12}"

cat > "${JOB_CONFIG}" <<'XML'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <actions/>
  <description>Task 2 local handover evidence</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>file:///task2-source</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/cicd-gitops</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="empty-list"/>
      <extensions/>
    </scm>
    <scriptPath>ci/Jenkinsfile</scriptPath>
    <lightweight>false</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
XML

docker run -d --rm \
  --name "${REGISTRY_CONTAINER}" \
  -p 5001:5000 \
  registry:2.8.3 >/dev/null

docker run -d --rm \
  --name "${JENKINS_CONTAINER}" \
  --user root \
  -p 18080:8080 \
  -e "JENKINS_ADMIN_PASS=${JENKINS_PASSWORD}" \
  -e "CASC_JENKINS_CONFIG=/casc/jenkins.yaml" \
  -e "JAVA_OPTS=-Djenkins.install.runSetupWizard=false -Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true" \
  -v "${JENKINS_HOME_DIR}:/var/jenkins_home" \
  -v "${REPO_ROOT}/ci/jenkins-casc.yaml:/casc/jenkins.yaml:ro" \
  -v "${SOURCE_DIR}:/task2-source:ro" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  "${JENKINS_IMAGE}" >/dev/null

wait_for_jenkins
refresh_crumb

curl -fsS -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
  -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" \
  -H "${CRUMB_FIELD}: ${CRUMB_VALUE}" \
  -F "jenkinsfile=<${REPO_ROOT}/ci/Jenkinsfile" \
  "${JENKINS_URL}/pipeline-model-converter/validate" \
  > "${EVIDENCE_DIR}/jenkinsfile-linter.txt"

curl -fsS -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
  -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" \
  -H "${CRUMB_FIELD}: ${CRUMB_VALUE}" \
  -H "Content-Type: application/xml" \
  --data-binary "@${JOB_CONFIG}" \
  "${JENKINS_URL}/createItem?name=${JOB_NAME}" >/dev/null

SUCCESS_BUILD="$(trigger_build build)"
SUCCESS_RESULT="$(wait_for_build "${SUCCESS_BUILD}")"
download_console "${SUCCESS_BUILD}" "${EVIDENCE_DIR}/jenkins-build-success.log"

if [[ "${SUCCESS_RESULT}" != "SUCCESS" ]]; then
  echo "Expected build ${SUCCESS_BUILD} to succeed, got ${SUCCESS_RESULT}." >&2
  exit 1
fi

curl -fsS -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
  "${JENKINS_URL}/job/${JOB_NAME}/${SUCCESS_BUILD}/artifact/scan-reports/pipeline-metadata.txt" \
  > "${EVIDENCE_DIR}/artifacts/pipeline-metadata.txt"
curl -fsS -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
  "${JENKINS_URL}/job/${JOB_NAME}/${SUCCESS_BUILD}/artifact/scan-reports/security-integration-status.txt" \
  > "${EVIDENCE_DIR}/artifacts/security-integration-status.txt"
curl -fsS "http://localhost:5001/v2/devsecops/tetris/tags/list" \
  | jq . > "${EVIDENCE_DIR}/local-registry-tags.json"

refresh_crumb
SECURITY_BUILD="$(
  trigger_build buildWithParameters \
    --data-urlencode "SECURITY_MODE=enforce"
)"
SECURITY_RESULT="$(wait_for_build "${SECURITY_BUILD}")"
download_console "${SECURITY_BUILD}" \
  "${EVIDENCE_DIR}/jenkins-security-enforce-failure.log"

if [[ "${SECURITY_RESULT}" != "FAILURE" ]]; then
  echo "Expected security build ${SECURITY_BUILD} to fail, got ${SECURITY_RESULT}." >&2
  exit 1
fi

refresh_crumb
ECR_BUILD="$(
  trigger_build buildWithParameters \
    --data-urlencode "REGISTRY_TARGET=ecr" \
    --data-urlencode "ECR_REGISTRY=" \
    --data-urlencode "SECURITY_MODE=stub"
)"
ECR_RESULT="$(wait_for_build "${ECR_BUILD}")"
download_console "${ECR_BUILD}" \
  "${EVIDENCE_DIR}/jenkins-ecr-parameter-failure.log"

if [[ "${ECR_RESULT}" != "FAILURE" ]]; then
  echo "Expected ECR validation build ${ECR_BUILD} to fail, got ${ECR_RESULT}." >&2
  exit 1
fi

docker run --rm "${JENKINS_IMAGE}" sh -lc \
  'docker --version; docker buildx version; aws --version; kustomize version' \
  > "${EVIDENCE_DIR}/jenkins-toolchain.txt" 2>&1

cat > "${STATE_FILE}" <<EOF
JENKINS_URL=${JENKINS_URL}
JOB_NAME=${JOB_NAME}
SUCCESS_BUILD=${SUCCESS_BUILD}
SECURITY_BUILD=${SECURITY_BUILD}
ECR_BUILD=${ECR_BUILD}
SOURCE_COMMIT=${SOURCE_COMMIT}
SOURCE_SHORT=${SOURCE_SHORT}
EOF

printf 'Jenkins evidence environment is ready.\n'
printf 'URL: %s/job/%s/%s/\n' "${JENKINS_URL}" "${JOB_NAME}" "${SUCCESS_BUILD}"
printf 'Local user: %s\n' "${JENKINS_USER}"
printf 'Build results: #%s=%s, #%s=%s, #%s=%s\n' \
  "${SUCCESS_BUILD}" "${SUCCESS_RESULT}" \
  "${SECURITY_BUILD}" "${SECURITY_RESULT}" \
  "${ECR_BUILD}" "${ECR_RESULT}"
printf 'Source snapshot: %s\n' "${SOURCE_COMMIT}"
printf 'Run cleanup-local-jenkins-evidence.sh after screenshots are captured.\n'
