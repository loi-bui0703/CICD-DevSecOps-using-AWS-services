# DevSecOps Factory
**Linh = Team-1 (Infra + CI/CD + K8s), My = Team-2 (Security), Loi = Team-3 (App + Dashboard)**
> **Local-first, cloud-after.** 

---

## Team ownership map

| Directory / File | Owner | Branch |
|---|---|---|
| `infrastructure/` · `ci/Jenkinsfile` · `docker-compose.infra.yml` · `kubernetes/` · `cd/` | **Team 1 — Linh** | `team/infra` |
| `security/` · `ci/stages/` · `docker-compose.security.yml` | **Team 2 — My** | `team/security` |
| `app/` · `monitoring/` · `docker-compose.obs.yml` | **Team 3 — Loi** | `team/app` |
| `shared/contracts/` · `docker-compose.yml` · `Makefile` | **All teams** | requires all reviews |


---

## Responsibilities

### Linh — Team 1 (Infrastructure + CI/CD + Kubernetes)
- Set up local stack: Jenkins, Gitea, local registry, k3d cluster
- Write `Jenkinsfile` (12-stage pipeline)
- Write `Dockerfile.agent` (CI agent with all required tools)
- Write `kubernetes/base/deployment.yaml` and Kustomize overlays for staging/production
- Configure ArgoCD to sync staging and production
- Write Terraform for cloud migration (AWS EKS + VPC + ECR)

### My — Team 2 (Security)
- Write 6 scan scripts in `ci/stages/`: secrets, sca, sast, container, iac, dast
- Set up SonarQube, DefectDojo, and OWASP ZAP
- Write Kyverno admission policies and Falco runtime rules
- Write aggregator script to upload findings to DefectDojo
- Define scan thresholds (CVSS score, severity level)

### Loi — Team 3 (App + Dashboard)
- Write `app/Dockerfile` (multi-stage, non-root, with `/health` endpoint)
- Put Tetris source code into `app/src/` — **with intentional vulnerabilities for demo** (see section below)
- Provide app spec to Linh: port, replicas, domain, env vars
- Build Grafana dashboards: app metrics + pipeline health
- Configure Prometheus, Loki, and Promtail

---

## Demo vulnerabilities in the app

The Tetris app contains **intentional vulnerabilities** so each security stage has findings to show during the demo. See `app/VULNERABILITIES.md` for full details.

# Example

| Stage | Vulnerability | File | Severity |
|---|---|---|---|
| ① Secrets scan | Fake AWS key in config | `app/src/config.js` | CRITICAL |
| ③ SCA | `lodash 4.17.4` has CVE-2019-10744 | `app/package.json` | HIGH |
| ④ SAST | `eval(userInput)` injection | `app/src/utils.js` | HIGH |
| ⑥ Container scan | Base image `node:14` has many CVEs | `app/Dockerfile` | CRITICAL |
| ⑦ IaC scan | `runAsNonRoot: false` in manifest | `kubernetes/base/deployment.yaml` | MEDIUM |

> Purpose: prove that each pipeline stage catches the exact type of vulnerability it is responsible for.

---

## Quick start

### Prerequisites (install once)

```bash
# macOS
brew install docker k3d kubectl helm make git

# Ubuntu
curl -fsSL https://get.docker.com | sh
curl -sfL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Clone and run

```bash
git clone https://github.com/lamelihuynh/devsecops-factory.git
cd devsecops-factory

# First time: copies env template and starts everything
make bootstrap
```

`make bootstrap` does:
1. Copies `shared/contracts/env-template.env` → `.env`
2. Creates shared Docker network
3. `docker compose up -d` (all 3 team modules)
4. Creates k3d cluster and connects it to local registry
5. Installs ingress-nginx and ArgoCD on the cluster

### Check everything is running

```bash
make status
```

---

## Access URLs

| Service | URL | Default credentials | Owner |
|---|---|---|---|
| Jenkins | http://localhost:8080 | admin / admin123 | Linh |
| Gitea | http://localhost:3000 | set on first visit | Linh |
| Registry | localhost:5001 | — | Linh |
| ArgoCD | https://localhost:8443 | admin / see `make argocd-install` | Linh |


**Change all passwords in `.env` before sharing access with teammates.**

---

## How the 3 members work in parallel

### The contract rule

The `shared/contracts/` folder is the **only** interface between teams. It defines:
- `ports.yaml` — every service port (no hardcoding anywhere else)
- `image-names.yaml` — registry URL + image name convention
- `env-template.env` — which env vars each team fills in

Any change to `shared/contracts/` requires a PR approved by **all members**.

### Git workflow

```
main  ←── PR (requires CODEOWNERS review) ←── team/infra     (Linh)
      ←── PR (requires CODEOWNERS review) ←── team/security  (My)
      ←── PR (requires CODEOWNERS review) ←── team/app       (Loi)
```

### Running each module independently

```bash
# Linh — Team 1
make up-infra

# My — Team 2 (needs network from Team 1 first)
docker network create devsecops
make up-security

# Loi — Team 3
make up-obs
```

### Full parallel startup

```bash
make up          # starts all 3 modules together
```

Docker Compose `include:` assembles `docker-compose.infra.yml` + `docker-compose.security.yml` + `docker-compose.obs.yml` into one stack. Each team only touches their own file.

---

## Project structure

```
devsecops-factory/
│
├── shared/contracts/              # ← ALL TEAMS READ THIS, nobody edits alone
│   ├── ports.yaml                 # Service port registry
│   ├── image-names.yaml           # Registry + image naming convention
│   └── env-template.env           # .env template (each team fills their section)
│
├── .github/
│   ├── CODEOWNERS                 # GitHub enforced ownership
│   └── workflows/
│       ├── infra-validate.yml     # Linh — Terraform + Helm + Dockerfile lint
│       ├── security-validate.yml  # My   — do not care
│       └── app-validate.yml       # Loi  — do not care
│
├── docker-compose.yml             # Root: includes all 3 team compose files
├── docker-compose.infra.yml       # Linh: Jenkins · Gitea · Registry
├── docker-compose.security.yml    # My:   ....
├── docker-compose.obs.yml         # Loi:  ....
├── Makefile                       # Unified CLI for all teams
│
├── infrastructure/                # ── LINH (Team 1) ──────────────────
│   ├── k3d/cluster.yaml           # Local Kubernetes (replaces EKS)
│   ├── terraform/                 # AWS IaC for cloud migration
│   │   ├── modules/vpc/
│   │   ├── modules/eks/
│   │   └── modules/ecr/
│   └── helm/                      # Helm values for in-cluster tools
│       ├── jenkins/
│       ├── argocd/
│       └── falco/
│
├── ci/                            # ── LINH + MY ──────────────────────
│   ├── Jenkinsfile                # LINH owns — pipeline orchestration
│   ├── Dockerfile.agent           # LINH owns — CI agent image
│   ├── jenkins-casc.yaml          # LINH owns — Jenkins config-as-code
│   └── stages/                    # MY owns — security scan scripts
│       ├── secrets-scan.sh
│       ├── sca-scan.sh
│       ├── sast-scan.sh
│       ├── container-scan.sh
│       ├── iac-scan.sh
│       └── dast-scan.sh
│
├── kubernetes/                    # ── LINH (Team 1) — written based on Loi's spec
│   ├── base/
│   │   └── deployment.yaml        # Deployment + Service + Ingress
│   └── overlays/
│       ├── staging/
│       │   └── kustomization.yaml
│       └── production/
│           └── kustomization.yaml
│
├── cd/                            # ── LINH 
│   └── apps/
│       └── argocd-apps.yaml       # ArgoCD Application CRDs
│
├── security/                      # ── MY  ────────────────────
│   ├── secrets-scanning/
│   ├── sast/
│   ├── sca/
│   ├── container/
│   ├── dast/
│   ├── runtime/
│   └── aggregation/
│
├── app/                           # ── LOI (Team 3) ───────────────────
│   ├── Dockerfile                 # multi-stage, non-root, /health endpoint
│   ├── VULNERABILITIES.md         # Documents all intentional vulnerabilities
│   └── src/                       # Tetris source — contains demo vulnerabilities
│
└── monitoring/                    # ── LOI (Team 3) ───────────────────
    ├── prometheus.yml              (Optional)
    ├── loki-config.yaml
    ├── promtail-config.yaml
    └── grafana/
        ├── dashboards/
        └── provisioning/
```

---

## Pipeline flow (end-to-end)

```
Loi pushes code to Gitea/GitHub
    ↓
Gitea webhook → Jenkins (Linh's pipeline)
    ↓
Jenkins Jenkinsfile stages:
  ① Secrets scan        (ci/stages/secrets-scan.sh — My's script)
  ② Build + unit tests  (npm — Linh orchestrates, Loi's app code)
  ③ SCA                 (ci/stages/sca-scan.sh — My's script)
  ④ SAST SonarQube      (ci/stages/sast-scan.sh — My's script)
  ⑤ Docker build        (Linh orchestrates, Loi's Dockerfile)
  ⑥ Container scan      (ci/stages/container-scan.sh — My's script)
  ⑦ IaC scan            (ci/stages/iac-scan.sh — My's script)
  ⑧ Push image → local registry
  ⑨ Bump image tag → ArgoCD auto-syncs staging (Linh's k8s manifests)
  ⑩ DAST ZAP vs staging (ci/stages/dast-scan.sh — My's script)
  ⑪ Manual approval gate
  ⑫ Promote → production (Linh's ArgoCD config)
    ↓
All scan results → DefectDojo (My's aggregator)
Metrics + logs  → Prometheus + Loki → Grafana (Loi's dashboards)
```
# Trouble Setting

**k3d cluster not pulling from local registry**
```bash
# Registry must be running BEFORE k3d cluster is created
make down
make up-infra
make k3d-create
```

**ArgoCD not syncing**
```bash
export KUBECONFIG=~/.kube/devsecops-local.kubeconfig
kubectl get pods -n argocd
kubectl logs -n argocd deployment/argocd-server
```

**Port already in use**
```bash
# Check shared/contracts/ports.yaml for the conflicting port, then free it
lsof -i :<port>
```

**Tetris app not accessible**
```bash
# Add to /etc/hosts
echo "127.0.0.1 tetris-staging.localhost" | sudo tee -a /etc/hosts
echo "127.0.0.1 tetris.localhost"         | sudo tee -a /etc/hosts
```

---

## Moving to cloud (AWS EKS)

```bash
# 1. Linh provisions AWS infrastructure
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars  # fill in AWS account details
terraform init && terraform apply

# 2. Update .env — only these 2 lines change
REGISTRY=<account>.dkr.ecr.us-east-1.amazonaws.com
KUBECONFIG_PATH=~/.kube/eks-cluster.kubeconfig

# 3. Install same Helm charts on EKS — zero pipeline changes
make argocd-install   # with EKS kubeconfig active
```

`Jenkinsfile` reads `REGISTRY` and `KUBECONFIG_PATH` from env — no code changes needed.

---

