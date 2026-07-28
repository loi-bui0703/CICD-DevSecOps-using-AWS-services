# DevSecOps Factory on AWS

Dự án tích hợp mã nguồn của Task 1–4 thành một luồng hoàn chỉnh trên branch
`cicd-gitops`: React Tetris → Jenkins security gates → Docker → Amazon ECR →
ECS Fargate staging → S3/Lambda/Security Hub → manual approval → ECS Fargate
production. Argo CD và k3d cung cấp đường GitOps local; Prometheus/Grafana cung
cấp quan sát local, còn CloudWatch nhận log và Container Insights trên AWS.

> This repository combines Tasks 1–4 into one runnable DevSecOps workflow.
> Vietnamese is the primary operational language; the English summary is below.

## Kiến trúc

```mermaid
flowchart LR
  A["Git commit"] --> B["Jenkins"]
  B --> C["Secrets / SCA / SAST / IaC"]
  C --> D["Docker build"]
  D --> E["Container scan"]
  E --> F["Amazon ECR"]
  F --> G["ECS staging"]
  F --> H["Argo CD staging (local k3d)"]
  G --> I["OWASP ZAP DAST"]
  H --> I
  I --> J["Normalize reports + ASFF"]
  J --> K["Amazon S3"]
  K --> L["Lambda importer"]
  L --> M["AWS Security Hub"]
  I --> N["Manual approval"]
  N --> O["ECS / Argo CD production"]
  G --> P["CloudWatch"]
  B --> Q["Prometheus + Grafana (local)"]
```

## Phần đã tích hợp

| Phạm vi | Thành phần chính |
|---|---|
| Task 1 – AWS | Terraform cho Budget, IAM, ECR, VPC, ALB, ECS Fargate, S3, CloudWatch và Lambda/Security Hub tùy chọn |
| Task 2 – CI/CD | Jenkins pipeline 21 stage, ECR, ECS, GitOps, S3, production approval và immutable SHA tag |
| Task 3 – Security | Gitleaks, Trivy, SonarQube, Checkov, ZAP, schema report thống nhất và ASFF |
| Task 4 – App | React app, multi-stage Dockerfile, hardened Kustomize overlays và ECS task-definition mẫu |
| Hoàn thiện chung | Compose thống nhất, Prometheus/Grafana/Blackbox, test report pipeline, validation và cleanup scripts |

## Chạy local

Yêu cầu: Docker Desktop/Engine, `make`, `kubectl`, Python 3 và tối thiểu 8 GB
RAM khả dụng nếu chạy cả Jenkins lẫn SonarQube.

```bash
make setup-env
# Sửa .env và thay toàn bộ giá trị change-me-before-use.
make up
make status
```

Các URL mặc định:

- Jenkins: <http://localhost:8080>
- SonarQube: <http://localhost:9000>
- Prometheus: <http://localhost:9090>
- Grafana: <http://localhost:3000>
- Docker Registry: `localhost:5001`

Chạy riêng từng lớp:

```bash
make up-infra
make up-security
make up-obs
```

## GitOps local với k3d

```bash
make k3d-create
make k3d-configure
make argocd-install
kubectl apply -f cd/apps/staging.yaml
kubectl apply -f cd/apps/production.yaml
```

Thêm vào `/etc/hosts` nếu hệ điều hành không tự ánh xạ `.localhost`:

```text
127.0.0.1 tetris-staging.localhost tetris.localhost
```

Argo CD đang trỏ tới repository/branch khai báo trong `cd/apps/*.yaml`. Hãy đổi
`repoURL` nếu bản tích hợp được đẩy sang repository khác.

## Jenkins

Tạo Multibranch Pipeline hoặc Pipeline from SCM với script path
`ci/Jenkinsfile`. Build mặc định an toàn cho local:

- `REGISTRY_TARGET=local`
- `SECURITY_MODE=stub`
- các side effect AWS/GitOps mặc định tắt

Jenkins dùng Docker-in-Docker cô lập trên network `devsecops`; controller không
chạy bằng root và không gắn Docker socket của máy host. Docker engine vẫn chạy
privileged bên trong Docker Desktop VM, vì vậy chỉ khởi động stack từ source đã
tin cậy và dừng stack khi kết thúc demo.

`ci/jenkins-job.xml` dùng bản clone local được mount read-only tại
`/workspace/source`, phù hợp khi GitHub repository là private nhưng chưa cấp PAT
cho Jenkins. Muốn dùng webhook/SCM trực tiếp, đổi URL trong job sang GitHub và
gắn credential `github-token`.

Luồng demo đầy đủ dùng:

- `DEMO_PRESET=FULL_AWS_DEMO` khi chạy qua `scripts/demo-trigger.sh`
- `REGISTRY_TARGET=ecr`
- `IMAGE_PLATFORM=linux/amd64` cho ECS Fargate mặc định
- `SECURITY_MODE=enforce`
- `SECURITY_BLOCK_SEVERITIES=CRITICAL` (hoặc `CRITICAL,HIGH`)
- `ENABLE_ECS_DEPLOY=true`
- `ENABLE_DAST=true`, `DAST_GATE_MODE=report-only` và `STAGING_URL` là URL ALB staging
- `ENABLE_S3_UPLOAD=true`
- `ENABLE_SECURITY_HUB_IMPORT=false` trong preset; chỉ bật ở custom build nếu Terraform đã bật importer
- `PROMOTE_PRODUCTION=true` để chờ manual approval

Pipeline dùng một tag 12 ký tự từ commit SHA cho cả staging và production.
Không ghi AWS key, GitHub token hoặc Sonar token vào repository.

### Demo AWS lặp lại

Jenkins checkout commit từ branch local, vì vậy hãy commit thay đổi trước khi
demo; không cần push GitHub. Giữ named volumes để cache Jenkins history,
Checkov, ZAP, Gitleaks và Trivy. Không dùng `docker compose down -v`.

```bash
cd /Users/loibui/Downloads/devsecops-factory/task-2
aws sso login --profile devsecops-factory
docker compose -f docker-compose.infra.yml up -d --build

# Đưa hai ECS service về desired count 0, không destroy Terraform:
AWS_PROFILE_NAME=devsecops-factory make demo-reset

# Tự đọc Terraform outputs và trigger preset đầy đủ:
make demo-trigger

# Chỉ kiểm tra preset/outputs, không trigger full build:
./scripts/demo-trigger.sh --dry-run
```

`demo-trigger` tự điền ECR, S3 bucket, staging URL, ECS family/cluster,
security enforce, DAST report-only và production manual gate. Script chỉ in URL
console/gate, không in Jenkins password hoặc AWS key. Nếu Jenkins chưa biết
parameter mới, script tự chạy một seed build local-safe trước. Khi kết thúc:

```bash
AWS_PROFILE_NAME=devsecops-factory make demo-reset
docker compose -f docker-compose.infra.yml down
```

## Triển khai AWS

Không chạy `terraform apply` trước khi xem chi phí và xác nhận email Budget:

```bash
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

Các task ECS mặc định bằng `0` để tránh phí Fargate ngoài giờ demo. Jenkins sẽ
scale chúng khi deploy, hoặc dùng:

```bash
scripts/scale-ecs.sh up
scripts/scale-ecs.sh down
```

`enable_security_hub_importer=false` theo mặc định. Chỉ chuyển thành `true` nếu
muốn bật Security Hub và Lambda S3 trigger. Gắn output
`jenkins_ci_policy_arn` vào IAM principal của Jenkins; ưu tiên IAM role/default
credential chain thay vì access key dài hạn.

Lưu ý chi phí: scale ECS về `0` chỉ dừng phí task. ALB, NAT/traffic, lưu trữ và
các dịch vụ khác vẫn có thể tính phí. Kết thúc demo, xem plan rồi cleanup:

```bash
CONFIRM_AWS_CLEANUP=devsecops-factory scripts/cleanup-aws.sh
# Muốn destroy toàn bộ:
CONFIRM_AWS_CLEANUP=devsecops-factory DESTROY_TERRAFORM=true scripts/cleanup-aws.sh
```

## Kiểm thử

```bash
scripts/validate.sh
FULL_BUILD=true scripts/validate.sh
```

Script kiểm tra shell, Python report/ASFF, Kustomize, Docker Compose, JSON và
Terraform. `FULL_BUILD=true` chạy thêm `npm ci` và build ứng dụng.

## Giới hạn đã biết

- Frontend giữ `react-scripts@3.4.0` và một số dependency cũ để phục vụ demo
  SCA; xem `app/VULNERABILITIES.md`. Đây không phải baseline phù hợp cho
  production thật.
- Repository không chứa `.env`, Terraform state, AWS key, GitHub token hay
  kubeconfig. Các giá trị này phải được cấp qua `.env`, Jenkins Credentials,
  IAM role/SSO hoặc secret manager.
- Terraform tạo hai ALB theo yêu cầu staging/production. Đây là phần có thể phát
  sinh phí ngay cả khi ECS desired count bằng `0`.
- Ảnh trong `results/` là bằng chứng lịch sử của từng task; kết quả tích hợp cuối
  nên được chụp lại sau khi chạy trên tài khoản AWS đích.

## English summary

The integrated branch provides a local-safe stack and an opt-in AWS release
path. Start locally with `make setup-env && make up`; validate with
`scripts/validate.sh`. Provision AWS only after reviewing the Terraform plan.
ECS tasks start at zero, Jenkins promotes an immutable commit-tagged image, and
production requires manual approval. Security reports are normalized, uploaded
to S3, and can be imported into Security Hub by an optional Lambda trigger.
