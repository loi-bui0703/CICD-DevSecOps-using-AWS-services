Xây dựng hệ thống CI/CD DevSecOps trên AWS cho ứng dụng Web React, sử dụng Jenkins, Docker, Amazon ECR, Amazon ECS Fargate, Amazon S3, AWS Lambda, Argo CD và CloudWatch.

## Tóm tắt

| Nhiệm vụ | Vai trò chính | Trọng tâm |
|---|---|---|
| 1 | AWS Infrastructure & Platform | AWS account, IAM, ECR, **ECS Fargate** (thay EKS), **S3** (reports), networking |
| 2 | CI/CD và GitOps | Jenkinsfile, pipeline, push image ECR, deploy ECS Fargate, Argo CD (local), promotion |
| 3 | DevSecOps Security | Secrets scan, SCA, SAST, IaC scan, container scan, DAST, **S3 lưu reports**, **Lambda aggregator** |
| 4 | Application, Docker, K8s & ECS Task | React app, Dockerfile, health check, K8s base/overlays, ECS Task Definition |
| 5 | Observability, QA, Documentation và Demo | CloudWatch, Prometheus/Grafana, kiểm thử, demo script và báo cáo |

pipeline end-to-end:

```text
React app -> Jenkins security gates -> Amazon ECR -> ECS Fargate (Staging) -> scan reports -> Amazon S3 -> AWS Lambda (aggregator) -> ECS Fargate (Production) -> CloudWatch
```

### Chủ đề 3 blog posts có thể xem xét

| Blog | Người phụ trách chính | Chủ đề |
|---|---|---|
| Blog 1 | Thành viên 1 + Thành viên 2 | Xây dựng CI/CD pipeline với Jenkins, Amazon ECR và Amazon ECS Fargate (thay EKS) |
| Blog 2 | Thành viên 3 | Tích hợp DevSecOps: secrets, SCA, SAST, container scan + lưu reports lên S3 + Lambda aggregator |
| Blog 3 | Thành viên 4 + Thành viên 5 | Deploy container lên ECS Fargate và giám sát với CloudWatch + Prometheus/Grafana |

Mỗi blog cần có:

- Vấn đề/bối cảnh.
- Dịch vụ AWS hoặc công cụ sử dụng.
- Các bước thực hiện chính.
- Ảnh minh họa.
- Bài học rút ra.
- Link tới project hoặc workshop nếu phù hợp.

### Yêu cầu song ngữ

Mỗi thành viên khi viết phần của mình phải cung cấp nội dung tiếng Việt trước, sau đó dịch sang tiếng Anh. Thành viên 5 chịu trách nhiệm rà lại để hai bản không lệch nghĩa.


### Yêu cầu làm việc chung

Mỗi người làm việc trên branch riêng:

| Thành viên | Branch |
|---|---|
| 1 | `aws-infra` |
| 2 | `cicd-gitops` |
| 3 | `security` |
| 4 | `app-k8s` |
| 5 | `observability-docs` |

Khi merge vào `main`, tạo pull request và ghi rõ:

- Mục tiêu thay đổi.
- File đã chỉnh.
- Cách kiểm thử.
- Ảnh chụp hoặc log chứng minh kết quả.
- Các rủi ro còn lại.

Một task được xem là hoàn thành khi có đủ:

- Code hoặc cấu hình đã được commit.
- Có lệnh kiểm thử hoặc ảnh chụp kết quả.
- Không làm hỏng phần đang chạy của người khác.
- Có ghi chú cách dùng trong tài liệu.
- Nếu là task AWS, có ghi chú cleanup để tránh phát sinh chi phí.

## Task 1 - AWS infrastructure và kubernetes platform

### Mô tả

Thành viên 1 chịu trách nhiệm xây dựng nền tảng AWS để ứng dụng có nơi chạy thật. 

### File/thư mục phụ trách

| File/thư mục | Công việc |
|---|---|
| `infrastructure/k3d/cluster.yaml` | Chuẩn hóa local Kubernetes để demo offline. |
| `infrastructure/terraform/` nếu tạo thêm | Viết IaC cho VPC, ECS Cluster, ECR, S3 nếu nhóm chọn Terraform. |
| `kubernetes/overlays/production/kustomization.yaml` | Phối hợp cập nhật ECR URI production. |
| `README.md` hoặc tài liệu phụ | Ghi hướng dẫn tạo AWS foundation. |
| AWS Console/AWS CLI | Tạo ECR, ECS Fargate, S3, IAM, budget. |

### Nhiệm vụ chi tiết

#### AWS-01 - Thiết lập AWS account an toàn

Việc cần làm:

- Bật MFA cho root user.
- Tạo IAM user hoặc IAM Identity Center user cho nhóm.
- Tạo AWS Budget theo tháng.
- Tạo cảnh báo chi phí ở mức 50%, 80%, 100%.
- Thống nhất region: khuyến nghị `ap-southeast-1`.

Kết quả bàn giao:

- Ảnh chụp AWS Budget.
- Ảnh chụp IAM user/role hoặc mô tả quyền.
- Ghi chú region và account ID đã dùng trong báo cáo.

Tiêu chí hoàn thành:

- Không dùng root user để thao tác hằng ngày.
- Có budget/cảnh báo chi phí trước khi tạo bất kỳ resource AWS nào.

#### AWS-02 - Tạo Amazon ECR

Việc cần làm:

- Tạo repository ECR cho image Tetris.
- Bật scan on push.
- Cung cấp ECR URI cho Thành viên 2 và Thành viên 4.

Tiêu chí hoàn thành:

- Repository tồn tại trên ECR.
- Có thể login Docker vào ECR.
- Thành viên 2 có thể push image từ Jenkins hoặc local test.

#### AWS-03 - Tạo Amazon ECS Fargate Cluster (thay EKS)

Lý do thay: EKS control plane tốn ~$72/tháng, không phù hợp ngân sách sinh viên. ECS Fargate không có phí cluster, chỉ trả tiền khi task đang chạy.

Việc cần làm:
- Tạo ECS Cluster với Fargate capacity provider.
- Tạo 2 ECS Services: `tetris-staging` và `tetris-production`.
- Cấu hình Application Load Balancer (ALB) cho từng environment.
- Tắt service khi không demo để tiết kiệm chi phí:

```bash
# Scale về 0 ngay sau khi demo xong
aws ecs update-service --cluster devsecops-factory \
  --service tetris-staging --desired-count 0
```

Kết quả bàn giao:
- Tên ECS Cluster.
- ALB URL staging và production.
- Ghi chú cách scale to 0 khi không demo.

Tiêu chí hoàn thành:
- ECS Cluster tồn tại ở trạng thái `ACTIVE`.
- ALB trả về response khi task đang chạy.
- Thành viên 2 và 4 deploy được qua ECS.

#### AWS-04 - Tạo Amazon S3 Bucket lưu Security Reports (dịch vụ mới)

Việc cần làm:
- Tạo S3 bucket lưu kết quả scan tập trung thay vì chỉ lưu trong Jenkins.
- Cấu hình các prefix: `reports/secrets/`, `reports/sca/`, `reports/sast/`, `reports/container/`, `reports/dast/`.
- Bật versioning và server-side encryption (SSE-S3).
- Bật lifecycle policy tự xóa reports sau 30 ngày.

Kết quả bàn giao:
- Tên S3 bucket và prefix structure.
- Ảnh chụp bucket settings.

Tiêu chí hoàn thành:
- Thành viên 3 có thể upload report từ Jenkins bằng `aws s3 cp`.
- Thành viên 3 deploy được Lambda đọc từ bucket này.

#### AWS-05 - Chuẩn hóa local k3d

Việc cần làm:

- Kiểm tra `infrastructure/k3d/cluster.yaml`.
- Thống nhất Docker network giữa k3d và docker-compose.
- Nếu cần demo offline, đảm bảo k3d pull được image từ local registry.

Điểm cần chú ý:

- Compose hiện dùng network `devsecops`.
- k3d config hiện dùng `devsecops-net`.
- Nên thống nhất một tên network để tránh lỗi.

Kết quả bàn giao:

- Lệnh tạo cluster local chạy được.
- Ảnh chụp `kubectl get nodes` với k3d.

### Phối hợp

| Cần từ ai | Nội dung |
|---|---|
| Thành viên 2 | Cần biết Jenkins cần quyền AWS gì để push ECR và deploy ECS. |
| Thành viên 3 | Cần biết cấu trúc S3 prefix và Lambda đọc report từ đâu. |
| Thành viên 4 | Cần biết port, health check, CPU/memory của app cho ECS task definition. |
| Thành viên 5 | Cần phối hợp CloudWatch, cost screenshot và phần báo cáo AWS foundation. |

### Checklist hoàn thành

- [x] AWS Budget đã tạo.
- [x] IAM access không dùng root user.
- [x] ECR repository đã tạo.
- [x] ECS Fargate Cluster tạo thành công (staging + production services).
- [x] S3 bucket tạo thành công, có đủ prefix cho từng loại scan.
- [x] Có hướng dẫn cleanup AWS (scale ECS về 0 ngay sau demo).
- [x] Có ảnh chụp minh chứng cho báo cáo.

## Task 2 - CI/CD và GitOps

### Mô tả

Thành viên 2 chịu trách nhiệm xây dựng luồng CI/CD từ lúc developer push code cho tới khi ứng dụng được deploy lên staging/production. Đây là phần trung tâm của đề tài DevOps on AWS.

### File/thư mục phụ trách

| File/thư mục | Công việc |
|---|---|
| `ci/Jenkinsfile` | Chuẩn hóa pipeline end-to-end. |
| `ci/jenkins-casc.yaml` | Cấu hình Jenkins credentials, environment, SonarQube nếu cần. |
| `ci/Dockerfile.master` | Đảm bảo Jenkins controller có công cụ cần thiết. |
| `ci/Dockerfile.agent` | Phối hợp nếu cần chạy agent riêng. |
| `cd/apps/staging.yaml` | Argo CD app staging. |
| `cd/apps/production.yaml` | Bổ sung Argo CD app production. |
| `docker-compose.infra.yml` | Jenkins và local registry nếu cần. |

### Chi tiết

#### CICD-01 - Chuẩn hóa Jenkins pipeline

Việc cần làm:

- Đọc lại `ci/Jenkinsfile`.
- Quyết định pipeline chạy trên repo hiện tại hay checkout repo ngoài.
- Chuẩn hóa biến môi trường:
  - `AWS_REGION`
  - `REGISTRY`
  - `REPO_NAME`
  - `IMAGE_NAME`
  - `IMAGE_TAG`
  - `SCAN_REPORT_DIR`
  - `TARGET_DIR`
- Đảm bảo các stage dùng cùng một source path.
- Với đồ án cá nhân/nhóm nhỏ, nên cho pipeline chạy trên chính repo này.
- Tránh vừa checkout `target-repo`, vừa build từ `./app`, vì dễ lệch đường dẫn.

Kết quả bàn giao:

- Jenkinsfile chạy được tới bước build image.
- Log pipeline rõ ràng.
- Có archive artifacts cho report security.

Tiêu chí hoàn thành:

- Một build Jenkins có thể chạy từ đầu tới cuối ở local hoặc AWS.
- Nếu security fail, pipeline phải báo lỗi dễ hiểu.

#### CICD-02 - Tích hợp push image lên Amazon ECR

Việc cần làm:

- Nhận ECR URI từ Thành viên 1.
- Thêm bước login ECR.
- Build image với tag theo commit SHA.
- Push image lên ECR.

Luồng mong muốn:

```text
git commit SHA -> docker build -> trivy image scan -> docker push ECR
```

Lệnh logic trong pipeline:

```bash
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${REGISTRY}"

docker build \
  -t "${IMAGE_NAME}:${IMAGE_TAG}" \
  -t "${IMAGE_NAME}:latest" \
  -f app/Dockerfile app

docker push "${IMAGE_NAME}:${IMAGE_TAG}"
docker push "${IMAGE_NAME}:latest"
```

Kết quả bàn giao:

- ECR có image tag mới sau khi Jenkins chạy.
- Ảnh chụp ECR repository.

Tiêu chí hoàn thành:

- Tag image không chỉ là `latest`, phải có tag theo commit hoặc build number.

#### CICD-03 - Hoàn thiện GitOps staging

Việc cần làm:

- Chọn mô hình GitOps:
  - Một repo duy nhất.
  - Hoặc tách repo app và repo infra.
- Sửa `cd/apps/staging.yaml` để trỏ đúng repo thật.
- Sau khi push image, Jenkins update `kubernetes/overlays/staging/kustomization.yaml`.
- Argo CD tự sync staging.

Luồng mong muốn:

```text
Jenkins push image -> Jenkins commit image tag vào GitOps repo -> Argo CD sync staging
```

Kết quả bàn giao:

- `cd/apps/staging.yaml` dùng repo đúng.
- Argo CD app staging có trạng thái `Synced` và `Healthy`.
- Có ảnh chụp Argo CD UI hoặc output CLI.

Tiêu chí hoàn thành:

- Push code mới có thể làm staging đổi sang image tag mới.

#### CICD-04 - Bổ sung GitOps production

Việc cần làm:

- Tạo nội dung cho `cd/apps/production.yaml`.
- Production dùng namespace `production`.
- Production dùng overlay `kubernetes/overlays/production`.
- Production chỉ được cập nhật sau manual approval.

Kết quả bàn giao:

- Production Argo CD app chạy được.
- Có manual approval gate trong Jenkins.
- Có quy trình promote staging -> production.

Tiêu chí hoàn thành:

- Không tự động deploy production khi chưa có approval.

#### CICD-05 - Chuẩn hóa Jenkins credentials

Việc cần làm:

- Tạo các credentials cần thiết:
  - Git token để push GitOps repo.
  - SonarQube token từ Thành viên 3.
  - AWS credentials hoặc IAM role.
  - Cosign key nếu có image signing.
- Ghi rõ credential ID trong tài liệu.

Kết quả bàn giao:

- Bảng credentials cần dùng.
- Không hardcode token vào repo.

Tiêu chí hoàn thành:

- Pipeline chạy không cần lộ secret trong code.

### Phối hợp

| Cần từ ai | Nội dung |
|---|---|
| Thành viên 1 | ECR URI, AWS permission, thông tin kết nối ECS Fargate. |
| Thành viên 3 | Scripts scan và quy định fail/pass. |
| Thành viên 4 | Dockerfile, app port, Kubernetes overlays. |
| Thành viên 5 | Demo script, screenshot pipeline, tổng hợp kết quả. |

### Checklist hoàn thành

- [x] Jenkins pipeline chạy end-to-end.
- [x] Image build thành công.
- [x] Image push lên ECR.
- [x] Jenkins archive security reports.
- [x] Argo CD staging sync thành công.
- [x] Production app được bổ sung.
- [x] Manual approval gate hoạt động.
- [x] Không hardcode secret.

## Task 3 - DevSecOps Security

### Mô tả

Thành viên 3 chịu trách nhiệm biến pipeline thông thường thành DevSecOps pipeline. Nhiệm vụ chính là xây dựng các cổng kiểm tra bảo mật trước khi image được deploy.

### File/thư mục phụ trách

| File/thư mục | Công việc |
|---|---|
| `ci/stages/secrets-scan.sh` | Implement secrets scan bằng Gitleaks/TruffleHog. |
| `ci/stages/sca-scan.sh` | Hoàn thiện SCA scan bằng Trivy filesystem. |
| `ci/stages/sast-scan.sh` | Hoàn thiện SonarQube/Semgrep scan. |
| `ci/stages/iac-scan.sh` | Sửa path và policy cho Checkov. |
| `ci/stages/container-scan.sh` | Thêm report JSON và exit code. |
| `ci/stages/dast-scan.sh` | Scan staging URL bằng OWASP ZAP. |
| `docker-compose.security.yml` | SonarQube, optional DefectDojo/ZAP service. |
| `app/VULNERABILITIES.md` | Ghi lại vulnerability demo nếu cần. |

### Chi tiết

#### SEC-01 - Implement secrets scan

Hiện trạng:

- `ci/stages/secrets-scan.sh` đang rỗng.

Việc cần làm:

- Implement Gitleaks.
- Nhận input từ `SCAN_DIR`.
- Xuất report vào `SCAN_REPORT_DIR`.
- Nếu phát hiện secret, pipeline fail.

Kết quả bàn giao:

- File script có thể chạy độc lập.
- Jenkins archive được `gitleaks-report.json`.

Tiêu chí hoàn thành:

- Khi cố tình thêm fake secret, pipeline phải fail.
- Khi không có secret, pipeline pass.

#### SEC-02 - Hoàn thiện SCA scan

Hiện trạng:

- `ci/stages/sca-scan.sh` đã có Trivy filesystem mode.

Việc cần làm:

- Đảm bảo scan đúng thư mục source.
- Tạo JSON report và HTML report.
- Thống nhất chính sách fail:
  - Fail nếu có CRITICAL.
  - HIGH có thể fail hoặc chỉ cảnh báo tùy giai đoạn demo.
- Giai đoạn đầu: `--soft-fail` hoặc không dùng `--exit-code 1` để lấy report.
- Giai đoạn demo cuối: bật `--exit-code 1` với CRITICAL để thể hiện security gate.

Kết quả bàn giao:

- `trivy-sca-report.json`.
- `trivy-sca-report.html`.
- Một đoạn giải thích SCA trong báo cáo.

#### SEC-03 - Bật SAST với SonarQube

Hiện trạng:

- `ci/stages/sast-scan.sh` đã có logic.
- Stage SAST trong `ci/Jenkinsfile` đang bị comment.

Việc cần làm:

- Khởi động SonarQube bằng `docker-compose.security.yml`.
- Tạo SonarQube token.
- Đưa token cho Thành viên 2 cấu hình Jenkins credential.
- Sửa script nếu đường dẫn source chưa đúng.
- Bật lại stage SAST trong Jenkinsfile.

Kiểm tra:

```bash
docker compose -f docker-compose.security.yml up -d sonarqube
```

Kết quả bàn giao:

- Dashboard SonarQube có project.
- Có ảnh chụp bugs/vulnerabilities/code smells.

Tiêu chí hoàn thành:

- Jenkins gọi được SonarQube scan.
- Không lộ Sonar token trong repo.

#### SEC-04 - Hoàn thiện IaC scan

Hiện trạng:

- `ci/stages/iac-scan.sh` đang scan `target-repo`.

Việc cần làm:

- Sửa script để dùng `SCAN_DIR`.
- Scan các thư mục:
  - `kubernetes/`
  - `cd/`
  - `infrastructure/`
  - `docker-compose*.yml`
- Xuất report JSON.

Kết quả bàn giao:

- `checkov_report.json`.
- Danh sách finding quan trọng và cách xử lý.

Tiêu chí hoàn thành:

- Checkov chạy ổn trong Jenkins.
- Finding được phân loại rõ: cần sửa ngay, có thể chấp nhận, false positive.

#### SEC-05 - Hoàn thiện container scan

Hiện trạng:

- `ci/stages/container-scan.sh` có Trivy image scan nhưng chưa xuất JSON report.

Việc cần làm:

- Thêm JSON output.
- Thêm policy fail theo CRITICAL.
- Archive report trong Jenkins.

Kết quả bàn giao:

- `container-scan-report.json`.
- Ảnh chụp hoặc log Trivy image scan.

Tiêu chí hoàn thành:

- Image phải được scan trước khi push hoặc trước khi promote production.

#### SEC-06 - Đổi DAST sang scan staging URL

Hiện trạng:

- `ci/stages/dast-scan.sh` đang tìm container `staging-app-local` và port 3000.
- Cách này không phù hợp khi deploy lên môi trường phân tán như ECS Fargate.

Việc cần làm:

- Nhận input `TARGET_URL`.
- Dùng OWASP ZAP baseline scan hoặc full scan.
- Xuất HTML, XML, JSON report.

Script logic:

```bash
TARGET_URL="${TARGET_URL:?TARGET_URL is required}"
REPORT_DIR="${REPORT_DIR:-scan-reports}"

docker run --rm \
  -v "${REPORT_DIR}:/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py \
  -t "${TARGET_URL}" \
  -r zap-report.html \
  -x zap-report.xml \
  -J zap-report.json
```

Kết quả bàn giao:

- `zap-report.html`.
- DAST stage chạy sau khi staging deploy.

Tiêu chí hoàn thành:

- DAST scan được URL staging thật.

### Phối hợp

| Cần từ ai | Nội dung |
|---|---|
| Thành viên 2 | Jenkins stage gọi đúng script và archive report (push lên S3). |
| Thành viên 4 | App có endpoint ổn định để DAST scan. |
| Thành viên 5 | Tổng hợp findings vào báo cáo và slide. |

#### SEC-07 - AWS Lambda Aggregator xử lý Security Reports (dịch vụ mới)

Việc cần làm:
- Viết một script (Python/Node.js) chạy trên AWS Lambda.
- Cấu hình Lambda trigger khi có file mới upload lên S3 bucket (được tạo ở Task 1).
- Chức năng: Đọc nội dung report (JSON), parse lỗi High/Critical, và có thể ghi log ra CloudWatch hoặc gọi webhook báo cho nhóm.

Kết quả bàn giao:
- Source code Lambda function.
- Ảnh chụp Lambda được trigger thành công trên AWS Console.

Tiêu chí hoàn thành:
- Khi đẩy file lên S3, Lambda tự động chạy và ghi log.

### Checklist hoàn thành

- [x] Secrets scan hoạt động.
- [x] SCA scan có report.
- [x] SAST SonarQube chạy được.
- [x] IaC scan dùng đúng đường dẫn.
- [x] Container scan có JSON report.
- [x] DAST scan staging URL.
- [x] **AWS Lambda** tự động xử lý report từ **S3**.
- [x] Có bảng security findings cho báo cáo.
- [x] Có đề xuất remediation.

## Task 4 - Application, Docker, Kubernetes Manifests và ECS Task Definition

### Mô tả

Thành viên 4 chịu trách nhiệm đảm bảo ứng dụng có thể build, container hóa và chạy ổn định trên Kubernetes (local) và ECS Fargate (cloud). Đây là phần nối giữa code ứng dụng và hạ tầng deploy.

### File/thư mục phụ trách

| File/thư mục | Công việc |
|---|---|
| `app/` | Kiểm tra app React, build, test, dependency. |
| `app/Dockerfile` | Tối ưu Docker image, non-root, health check nếu cần. |
| `app/VULNERABILITIES.md` | Ghi chú vulnerability demo hoặc tình trạng bảo mật app. |
| `kubernetes/base/deployment.yaml` | Deployment, Service, Ingress, probes, securityContext. |
| `kubernetes/base/service.yaml` | Quyết định giữ/sửa/xóa hoặc ghi chú legacy. |
| `kubernetes/overlays/staging/kustomization.yaml` | Staging config. |
| `kubernetes/overlays/production/kustomization.yaml` | Production config. |

### Chi tiết

#### APP-01 - Kiểm tra app React build được

Việc cần làm:

- Chạy `npm install`.
- Chạy `npm run build`.
- Kiểm tra app chạy local.
- Ghi lại lỗi nếu dependency cũ gây warning.

Lệnh:

```bash
cd app
npm install
npm run build
```

Kết quả bàn giao:

- Ảnh chụp build thành công.
- Nếu build lỗi, ghi rõ nguyên nhân và cách sửa.

Tiêu chí hoàn thành:

- `app/build` được tạo thành công.

#### APP-02 - Chuẩn hóa Dockerfile

Hiện trạng:

- `app/Dockerfile` dùng Node 16 để build.
- Stage runtime dùng `nginxinc/nginx-unprivileged:alpine`.
- App expose port 8080.

Việc cần làm:

- Kiểm tra Dockerfile build được.
- Đảm bảo runtime không chạy root.
- Kiểm tra Nginx serve đúng static files.
- Nếu cần, thêm health endpoint hoặc dùng `/` làm health check như manifest hiện tại.

Lệnh test:

```bash
docker build -t devsecops/tetris:local -f app/Dockerfile app
docker run --rm -p 8088:8080 devsecops/tetris:local
```

Kết quả bàn giao:

- Image local chạy được.
- App mở được ở `http://localhost:8088`.

Tiêu chí hoàn thành:

- Thành viên 2 có thể dùng Dockerfile này trong Jenkins.
- Thành viên 3 có thể scan image.

#### APP-03 - Chuẩn hóa Kubernetes base manifest

Việc cần làm:

- Kiểm tra `kubernetes/base/deployment.yaml`.
- Đảm bảo container port là 8080.
- Đảm bảo Service target port là 8080.
- Giữ probes:
  - livenessProbe
  - readinessProbe
- Giữ securityContext:
  - `runAsNonRoot`
  - `allowPrivilegeEscalation: false`
  - `readOnlyRootFilesystem`
  - `capabilities.drop: ["ALL"]`

Điểm cần xử lý:

- `kubernetes/base/service.yaml` có `targetPort: 80`, không khớp với app runtime 8080.
- `base/kustomization.yaml` hiện chỉ include `deployment.yaml`.
- Cần quyết định:
  - Hoặc bỏ `service.yaml` khỏi phạm vi sử dụng.
  - Hoặc sửa `service.yaml` và tách Service khỏi `deployment.yaml`.
- Để đơn giản, giữ all-in-one trong `deployment.yaml`.
- Ghi chú `service.yaml` là file legacy hoặc xóa ở giai đoạn dọn dẹp nếu nhóm đồng ý.

Kết quả bàn giao:

- `kubectl kustomize kubernetes/overlays/staging` chạy được.
- `kubectl kustomize kubernetes/overlays/production` chạy được.

#### APP-04 - Chuẩn hóa staging overlay

Việc cần làm:

- Staging replicas = 1.
- Staging dùng image từ local registry khi demo local, hoặc ECR khi demo AWS.
- Host staging rõ ràng:
  - Local: `tetris-staging.localhost`
  - AWS: ALB DNS hoặc domain staging.

Kiểm tra:

```bash
kubectl kustomize kubernetes/overlays/staging
```

Kết quả bàn giao:

- Staging deploy được.
- URL staging được cung cấp cho Thành viên 3 để chạy DAST.

#### APP-05 - Chuẩn hóa production overlay

Việc cần làm:

- Production replicas tối thiểu 2 hoặc 3.
- Production dùng ECR image URI.
- Production resources cao hơn staging.
- Thêm HPA nếu kịp.
- Thêm PodDisruptionBudget nếu kịp.

Kết quả bàn giao:

- `kubernetes/overlays/production/kustomization.yaml` dùng đúng ECR URI.
- Manifest production phù hợp cho demo HA cơ bản.

Tiêu chí hoàn thành:

- Production deploy được qua Argo CD.
- Không còn image URI sai hoặc hardcode tài khoản AWS cũ.

#### APP-06 - Viết tài liệu app và vulnerability demo

Việc cần làm:

- Cập nhật `app/README.md` nếu cần.
- Cập nhật `app/VULNERABILITIES.md` để ghi:
  - Dependency cũ nào tạo finding SCA.
  - Docker base image có finding nào.
  - App có điểm nào dùng để demo security scan.

Kết quả bàn giao:

- Thành viên 5 có nội dung để đưa vào báo cáo.
- Thành viên 3 có thông tin để giải thích security findings.

#### APP-07 - Khởi tạo ECS Task Definition (dịch vụ mới)

Việc cần làm:

- Viết file `ecs-task-def.json` định nghĩa container.
- Cấu hình ECR image URI, port mapping 8080, log configuration `awslogs`.
- Khai báo task execution role và task role.

Kết quả bàn giao:

- File `ecs-task-def.json` commit vào repo.
- Đã test deploy thử nghiệm lên ECS.

Tiêu chí hoàn thành:

- ECS Fargate có thể pull image và chạy task thành công.

### Phối hợp

| Cần từ ai | Nội dung |
|---|---|
| Thành viên 1 | ECS Fargate cluster, ECR URI, ALB setup. |
| Thành viên 2 | Jenkins build path và image tag convention. |
| Thành viên 3 | Security findings liên quan app/container. |
| Thành viên 5 | Test case và tài liệu demo app. |

### Checklist hoàn thành

- [x] App React build được.
- [x] Docker image chạy local được.
- [x] Kubernetes base manifest hợp lệ.
- [x] Staging overlay deploy được.
- [x] Production overlay deploy được.
- [x] Container port, Service targetPort, probes khớp nhau.
- [x] ECS Task Definition (`ecs-task-def.json`) đã được tạo.
- [x] App documentation được cập nhật.

## Task5 - Observability, QA, Documentation và Demo

### Mô tả

Thành viên 5 chịu trách nhiệm chứng minh hệ thống hoạt động được, quan sát được và trình bày được, dồ án không chỉ cần code, mà còn cần báo cáo, ảnh chụp, demo script và đánh giá kết quả.

### File/thư mục phụ trách

| File/thư mục | Công việc |
|---|---|
| `guide.md` | Cập nhật nếu có thay đổi hướng triển khai. |
| `task.md` | Theo dõi phân công và tiến độ. |
| `README.md` | Cập nhật hướng dẫn chạy demo nếu cần. |
| `monitoring/` nếu tạo thêm | Cấu hình monitoring local nếu nhóm muốn. |
| Báo cáo/slide ngoài repo | Tổng hợp nội dung đồ án. |
| CloudWatch Console | Logs, metrics, alarm, Container Insights. |

### Chi tiết

#### OBS-01 - Bật CloudWatch Container Insights cho ECS

Việc cần làm:

- Phối hợp với Thành viên 1 để bật CloudWatch Container Insights cho ECS cluster.
- Kiểm tra logs/metrics xuất hiện trong CloudWatch.
- Chụp màn hình dashboard/log groups.

Kiểm tra:

```bash
aws ecs update-cluster-settings \
  --cluster devsecops-factory \
  --settings name=containerInsights,value=enabled \
  --region ap-southeast-1
```

Kết quả bàn giao:

- Ảnh chụp Container Insights.
- Ảnh chụp log group liên quan ECS/app.

Tiêu chí hoàn thành:

- Có ít nhất một dashboard hoặc log screenshot dùng được trong báo cáo.

#### OBS-02 - Tạo checklist kiểm thử end-to-end

Việc cần làm:

- Viết test case cho từng phần:
  - App build.
  - Docker image build.
  - Security scan fail/pass.
  - ECR push.
  - Argo CD sync.
  - ECS deploy.
  - CloudWatch logs.
  - Production approval.
- Mỗi test case cần có:
  - Mục tiêu.
  - Bước thực hiện.
  - Kết quả mong đợi.
  - Người phụ trách.
  - Ảnh/log chứng minh.

Kết quả bàn giao:

- Bảng test case trong báo cáo.
- Danh sách screenshot cần chụp.

Tiêu chí hoàn thành:

- Nhóm có thể chạy demo theo checklist mà không bị quên bước.

#### OBS-03 - Tổng hợp security findings

Việc cần làm:

- Nhận report từ Thành viên 3.
- Tổng hợp thành bảng:
  - Tool.
  - Loại lỗi.
  - Severity.
  - File/image affected.
  - Cách xử lý.
  - Trạng thái.

Bảng mẫu:

| Tool | Loại kiểm tra | Finding | Severity | Cách xử lý | Trạng thái |
|---|---|---|---|---|---|
| Gitleaks | Secrets | Không có secret thật | Pass | Không cần xử lý | Done |
| Trivy FS | SCA | Dependency cũ | High | Update/chấp nhận risk demo | In review |
| Checkov | IaC | Thiếu policy | Medium | Bổ sung manifest hardening | Done |
| Trivy Image | Container | CVE base image | High | Đổi base image/cập nhật image | Todo |
| ZAP | DAST | Header warning | Low | Bổ sung security headers | Todo |

Kết quả bàn giao:

- Bảng findings trong báo cáo.
- Một slide giải thích DevSecOps gates.

#### OBS-04 - Xây dựng workshop website song ngữ

Theo quy định mới, báo cáo cuối khóa phải là **workshop website** dựa trên template `FCAJ-workshop-template`, không chỉ là slide hoặc file báo cáo thường.

Việc cần làm:

- Tạo bản workshop riêng từ template FCAJ, không copy y nguyên workshop mẫu.
- Tổ chức nội dung thành 2 ngôn ngữ `vi` và `en`.
- Tạo navigation rõ ràng.
- Thêm hình ảnh minh họa, sơ đồ kiến trúc, code block và screenshot.
- Đính kèm hoặc link tới các file kỹ thuật quan trọng: Dockerfile, Jenkinsfile, scripts, Kubernetes manifests.
- Đảm bảo phần Workshop có thể được người khác làm theo end-to-end.

Cấu trúc bắt buộc:

1. Student Information.
2. Worklog Week 1-12.
3. Proposal.
4. Blogs Post.
5. Events Participated.
6. Workshop.
7. Self-evaluation.
8. Sharing and Feedback.

Phần Thành viên 5 tự viết chính:

- Trang tổng quan workshop.
- Trang proposal.
- Worklog Week 1-12.
- Kế hoạch kiểm thử.
- Tổng hợp kết quả.
- Self-evaluation template.
- Sharing and feedback template.
- Bản tiếng Anh tương ứng.

Các thành viên khác cung cấp nội dung kỹ thuật chi tiết cho phần mình bằng tiếng Việt; Thành viên 5 điều phối bản dịch tiếng Anh.

Kết quả bàn giao:

- Workshop website hoàn chỉnh.
- Nội dung chính có đủ `vi/en`.
- Slide demo.
- Demo script 10 phút.
- Bộ screenshot và file đính kèm.

#### OBS-05 - Điều phối 3 blog posts và events

Việc cần làm:
- Thu thập link hoặc ảnh chụp bài đã đăng 3 blog posts đăng trên AWS Study Group.
- Thu thập thông tin events participated của từng thành viên.
- Với mỗi event, ghi đủ:
  - Tên sự kiện.
  - Thời gian.
  - Địa điểm.
  - Vai trò.
  - Nội dung chính.
  - Hình ảnh hoặc video chứng minh tham gia.
  - Bài học rút ra hoặc đóng góp cá nhân.

Kết quả bàn giao:

- Link hoặc screenshot chứng minh đã đăng 3 blog posts trên AWS Study Group.
- Trang Events Participated có minh chứng.

#### OBS-06 - Thu thập self-evaluation và feedback

Việc cần làm:

- Gửi form hoặc mẫu nội dung cho từng thành viên tự đánh giá.
- Mỗi người tự đánh giá theo các tiêu chí:
  - Kiến thức.
  - Khả năng học hỏi.
  - Tính chủ động.
  - Kỷ luật.
  - Giao tiếp.
  - Teamwork.
  - Giải quyết vấn đề.
  - Đóng góp cho dự án.
- Mỗi tiêu chí chọn Tốt/Khá/Trung bình và có nhận xét.
- Thu thập Sharing and Feedback:
  - Cảm nhận về chương trình.
  - Mức độ hài lòng.
  - Điểm cần cải thiện.
  - Có giới thiệu chương trình cho bạn bè không và vì sao.

Kết quả bàn giao:

- Trang Self-evaluation hoàn chỉnh.
- Trang Sharing and Feedback hoàn chỉnh.

#### OBS-07 - Chuẩn bị demo script

Luồng demo khuyến nghị:

1. Giới thiệu đề tài và kiến trúc.
2. Mở repo, chỉ ra các thư mục chính.
3. Tạo commit thay đổi nhỏ trong app.
4. Push code.
5. Jenkins chạy pipeline.
6. Security scans sinh report.
7. Image được push lên ECR.
8. GitOps repo được update image tag.
9. Argo CD sync staging.
10. Mở app qua ALB URL.
11. Mở CloudWatch logs/metrics.
12. Manual approval để promote production nếu còn thời gian.

Kết quả bàn giao:

- Kịch bản demo từng bước.
- Danh sách người nói từng phần.
- Danh sách ảnh backup nếu demo live lỗi.

### Phối hợp

| Cần từ ai | Nội dung |
|---|---|
| Thành viên 1 | AWS screenshots, cost, ECS Fargate, S3, ECR, CloudWatch. |
| Thành viên 2 | Jenkins logs, Argo CD screenshots. |
| Thành viên 3 | Security reports và findings. |
| Thành viên 4 | App screenshot, Docker/Kubernetes manifest explanation. |

### Checklist hoàn thành

- [x] CloudWatch có log/metric screenshot.
- [x] Test case end-to-end hoàn chỉnh.
- [ ] Workshop website có cấu trúc đúng template FCAJ.
- [ ] Nội dung chính có đủ tiếng Việt và tiếng Anh.
- [ ] Worklog có đủ Week 1 đến Week 12.
- [ ] Proposal có đủ tổng quan, mục tiêu, vấn đề, kiến trúc, timeline, ngân sách, rủi ro.
- [ ] Có 3 blog posts để đăng AWS Study Group.
- [ ] Events Participated có minh chứng.
- [ ] Self-evaluation hoàn chỉnh.
- [ ] Sharing and Feedback hoàn chỉnh.
- [ ] Slide demo có kiến trúc và kết quả.
- [ ] Demo script 10 phút có phân vai.
- [x] Có checklist cleanup AWS.
- [x] Có ảnh backup cho trường hợp demo live lỗi.

## Roadmap 12 tuần mẫu để viết worklog

### Tuần 1 - Khởi động và phân tích

| Thành viên | Việc cần làm | Kết quả |
|---|---|---|
| Thành viên 1 | Tìm hiểu AWS account, IAM, Budget, ECS Fargate/ECR/S3. | Ghi chú AWS foundation và cost risk. |
| Thành viên 2 | Đọc Jenkinsfile, vẽ luồng pipeline hiện tại. | Sơ đồ pipeline hiện trạng. |
| Thành viên 3 | Đọc các script security scan. | Bảng script nào đã có, script nào thiếu. |
| Thành viên 4 | Chạy thử app React và Dockerfile. | Kết quả build/run local. |
| Thành viên 5 | Tổng hợp `guide.md`, tạo outline báo cáo. | Dàn ý báo cáo và kế hoạch demo. |

### Tuần 2 - App và Docker baseline

| Thành viên | Việc cần làm | Kết quả |
|---|---|---|
| Thành viên 1 | Chuẩn bị AWS CLI profile, tạo budget. | AWS account sẵn sàng. |
| Thành viên 2 | Sửa Jenkinsfile để build app nhất quán. | Pipeline build được Docker image local. |
| Thành viên 3 | Implement secrets scan. | Gitleaks report. |
| Thành viên 4 | Chuẩn hóa Dockerfile và app build. | Image chạy local port 8080. |
| Thành viên 5 | Viết test case app/Docker baseline. | Checklist kiểm thử ban đầu. |

### Tuần 3 - Security gates

| Thành viên | Việc cần làm | Kết quả |
|---|---|---|
| Thành viên 1 | Tạo ECR repository. | ECR URI bàn giao cho nhóm. |
| Thành viên 2 | Tích hợp archive report trong Jenkins. | Jenkins lưu report security. |
| Thành viên 3 | Hoàn thiện SCA, SAST, IaC, container scan. | Security scan reports. |
| Thành viên 4 | Sửa manifest theo finding bảo mật. | K8s manifest hardening. |
| Thành viên 5 | Tổng hợp bảng findings. | Security findings table. |

### Tuần 4 - ECR và image delivery

| Thành viên | Việc cần làm | Kết quả |
|---|---|---|
| Thành viên 1 | Kiểm tra ECR permission và login. | Jenkins/local push được image. |
| Thành viên 2 | Jenkins push image lên ECR. | ECR có image tag commit SHA. |
| Thành viên 3 | Container scan trước push/promote. | Container report. |
| Thành viên 4 | Cập nhật image name trong overlays. | Kustomize dùng ECR URI đúng. |
| Thành viên 5 | Chụp ảnh ECR và cập nhật báo cáo. | Minh chứng image registry. |

### Tuần 5 - ECS Fargate và K8s local deploy

| Thành viên | Việc cần làm | Kết quả |
|---|---|---|
| Thành viên 1 | Tạo ECS Fargate Cluster và S3 Bucket. | ECS Cluster active, S3 created. |
| Thành viên 2 | Chuẩn bị Argo CD (local k3d) & Jenkins deploy ECS. | Argo CD chạy local, Jenkins deploy ECS. |
| Thành viên 3 | IaC scan manifests & test Lambda aggregator. | Checkov report, Lambda code. |
| Thành viên 4 | Deploy staging lên ECS Fargate. | App chạy trên ECS staging. |
| Thành viên 5 | Ghi test case deploy ECS Fargate. | Screenshot ECS tasks/services/ALB. |

### Tuần 6 - GitOps staging và production

| Thành viên | Việc cần làm | Kết quả |
|---|---|---|
| Thành viên 1 | Hỗ trợ IAM/Kubernetes permission cho Argo CD. | Argo CD sync được. |
| Thành viên 2 | Hoàn thiện staging/production Argo CD apps. | Staging auto-sync, production có app. |
| Thành viên 3 | DAST scan staging URL. | ZAP report. |
| Thành viên 4 | Tối ưu production overlay, replicas, resources. | Production manifest sẵn sàng. |
| Thành viên 5 | Cập nhật demo script GitOps. | Demo auto deploy rõ ràng. |

### Tuần 7 - Monitoring, logging và tối ưu

| Thành viên | Việc cần làm | Kết quả |
|---|---|---|
| Thành viên 1 | Hỗ trợ CloudWatch addon và AWS cleanup plan. | CloudWatch enabled. |
| Thành viên 2 | Thêm build summary trong Jenkins. | Pipeline dễ trình bày. |
| Thành viên 3 | Chốt security policy và remediation. | Security section hoàn chỉnh. |
| Thành viên 4 | Thêm HPA/PDB nếu kịp. | Production ổn định hơn. |
| Thành viên 5 | Tổng hợp logs, metrics, screenshots. | Observability section hoàn chỉnh. |

### Tuần 8 - Hoàn thiện kỹ thuật và diễn tập demo kỹ thuật

| Thành viên | Việc cần làm | Kết quả |
|---|---|---|
| Thành viên 1 | Chuẩn bị phần trình bày AWS (ECS Fargate, S3, IAM). | Slide AWS foundation. |
| Thành viên 2 | Chuẩn bị phần trình bày Jenkins/GitOps. | Slide CI/CD flow. |
| Thành viên 3 | Chuẩn bị phần trình bày DevSecOps (Lambda Aggregator). | Slide security gates & Lambda. |
| Thành viên 4 | Chuẩn bị phần trình bày app/ECS. | Slide app deployment. |
| Thành viên 5 | Ghép slide kỹ thuật, chạy rehearsal kỹ thuật. | Demo kỹ thuật ổn định. |

### Tuần 9 - Dựng workshop website và nội dung song ngữ

| Thành viên | Việc cần làm | Kết quả |
|---|---|---|
| Thành viên 1 | Viết phần AWS foundation bằng tiếng Việt: IAM, Budget, ECR, ECS Fargate, S3, cleanup. | Nội dung AWS foundation bản `vi`. |
| Thành viên 2 | Viết phần CI/CD và GitOps bằng tiếng Việt. | Nội dung Jenkins/Argo CD bản `vi`. |
| Thành viên 3 | Viết phần DevSecOps (bao gồm Lambda) bằng tiếng Việt. | Nội dung security bản `vi`. |
| Thành viên 4 | Viết phần app, Docker, ECS task definition bằng tiếng Việt. | Nội dung app/ECS bản `vi`. |
| Thành viên 5 | Tạo workshop website từ template FCAJ, tạo navigation, bắt đầu bản dịch `en`. | Website có khung `vi/en`. |

### Tuần 10 - Hoàn thiện workshop step-by-step

| Thành viên | Việc cần làm | Kết quả |
|---|---|---|
| Thành viên 1 | Chụp screenshot AWS Console/CLI: Budget, ECR, ECS Fargate, S3, ALB, CloudWatch. | Bộ ảnh minh chứng AWS. |
| Thành viên 2 | Chụp screenshot Jenkins pipeline và Argo CD sync (local). | Bộ ảnh CI/CD và GitOps. |
| Thành viên 3 | Chụp screenshot/report security scans và Lambda execution. | Bộ ảnh security findings. |
| Thành viên 4 | Chụp screenshot app, Docker build, ECS workloads. | Bộ ảnh app/deployment. |
| Thành viên 5 | Viết workshop lab từng bước, thêm code snippet, ảnh và kết quả mong đợi. | Workshop có thể làm theo end-to-end. |

### Tuần 11 - Blogs, events, self-evaluation và feedback

| Thành viên | Việc cần làm | Kết quả |
|---|---|---|
| Thành viên 1 | Viết/review Blog 1 về AWS foundation, ECR/ECS Fargate/S3. | Nội dung blog có phần AWS. |
| Thành viên 2 | Viết/review Blog 1 về Jenkins CI/CD và GitOps. | Blog 1 hoàn chỉnh. |
| Thành viên 3 | Viết Blog 2 về DevSecOps security gates & Lambda aggregator. | Blog 2 hoàn chỉnh. |
| Thành viên 4 | Viết/review Blog 3 về Docker/ECS deployment. | Nội dung blog có phần app/ECS. |
| Thành viên 5 | Viết/review Blog 3 về CloudWatch/cost, thu thập events, self-evaluation, feedback. | 3 blog posts, events và self-evaluation sẵn sàng. |

### Tuần 12 - Rà soát thang điểm và nộp bản cuối

| Thành viên | Việc cần làm | Kết quả |
|---|---|---|
| Thành viên 1 | Kiểm tra cleanup AWS, xác nhận không còn resource tốn phí ngoài kế hoạch. | Cleanup checklist hoàn chỉnh. |
| Thành viên 2 | Chạy lại pipeline hoặc chuẩn bị log thành công cuối cùng. | Bằng chứng CI/CD cuối cùng. |
| Thành viên 3 | Chốt bảng findings và remediation. | Security section hoàn chỉnh. |
| Thành viên 4 | Chốt app/deployment screenshots, kiểm tra file đính kèm. | App/ECS section hoàn chỉnh. |
| Thành viên 5 | Rà soát song ngữ, template, navigation, lỗi chính tả, rehearsal cuối. | Workshop website và slide sẵn sàng nộp. |

## Checklist tích hợp cuối cùng

Trước ngày nộp, cả nhóm phải cùng kiểm tra:

- [x] AWS Budget đã bật.
- [x] ECR có image mới.
- [x] ECS Fargate cluster active và chạy đúng 2 services (staging, production).
- [x] S3 Bucket nhận file report và kích hoạt Lambda thành công.
- [x] Jenkins pipeline chạy end-to-end.
- [x] Secrets scan hoạt động.
- [x] SCA scan hoạt động.
- [x] SAST scan hoạt động hoặc có giải thích nếu chưa bật.
- [x] IaC scan hoạt động.
- [x] Container scan hoạt động.
- [x] DAST scan được staging URL.
- [x] Argo CD staging `Synced` và `Healthy`.
- [x] Production có manual approval hoặc quy trình promote rõ ràng.
- [x] CloudWatch có logs/metrics.
- [x] Project dùng ít nhất 3 dịch vụ AWS và có giải thích lý do chọn từng dịch vụ.
- [ ] Workshop website dựa trên template FCAJ.
- [ ] Nội dung chính có đủ `vi/en`.
- [ ] Worklog có đủ Week 1 đến Week 12.
- [ ] Proposal có tổng quan, mục tiêu, vấn đề, kiến trúc, timeline, ngân sách, rủi ro.
- [ ] Có 3 blog posts để đăng AWS Study Group.
- [ ] Có Events Participated kèm minh chứng.
- [ ] Có Self-evaluation.
- [ ] Có Sharing and Feedback.
- [ ] Báo cáo có ảnh chụp chứng minh, sơ đồ kiến trúc, code snippet và file đính kèm.
- [x] Có script cleanup AWS sau demo.
