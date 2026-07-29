# Checklist Kiểm thử End-to-End (QA & Testing Suite)

**Dự án**: AWS DevSecOps Pipeline — Tetris Web App  
**Người lập**: Thành viên 5 (Observability, QA, Documentation & Demo)  
**Ngày cập nhật**: 2026-07-27

---

## 📌 Quy trình & Tiêu chí Đánh giá Kiểm thử

Một Test Case được coi là **PASS (Đạt)** khi đáp ứng đủ 4 điều kiện:

1. Thực hiện đúng các bước miêu tả trong kịch bản (Steps).
2. Kết quả thực tế khớp hoàn toàn với kết quả mong đợi (Expected Output).
3. Có bằng chứng xác minh (Command output / Log / Screenshot đính kèm).
4. Không gây ảnh hưởng tới các dịch vụ đang chạy của thành viên khác.

---

## 🧪 Bảng Checklist Kiểm thử Chi tiết (7 Giai đoạn End-to-End)

### Giai đoạn 1: AWS Infrastructure & Platform (Thành viên 1)

| Mã TC         | Hạng mục kiểm thử          | Các bước thực hiện                                     | Kết quả mong đợi                                                                       | Người PT     | Phương pháp xác minh                    | Trạng thái    |
| ------------- | -------------------------- | ------------------------------------------------------ | -------------------------------------------------------------------------------------- | ------------ | --------------------------------------- | ------------- |
| **TC-AWS-01** | AWS Account & Budget       | 1. Mở AWS Billing Console.<br>2. Kiểm tra AWS Budgets. | Có Budget $10/tháng và cảnh báo ở mức 50%, 80%, 100%.                                  | Thành viên 1 | AWS Console Screenshot                  | `[ ] Pending` |
| **TC-AWS-02** | Amazon ECR Repository      | 1. Chạy `aws ecr describe-repositories`.               | ECR repository `devsecops/tetris` tồn tại, bật _Scan on push_.                         | Thành viên 1 | AWS CLI `aws ecr describe-repositories` | `[ ] Pending` |
| **TC-AWS-03** | Amazon ECS Fargate Cluster | 1. Chạy `aws ecs describe-clusters`.                   | Cluster `devsecops-factory` trạng thái `ACTIVE` với Fargate provider.                  | Thành viên 1 | AWS CLI `aws ecs describe-clusters`     | `[ ] Pending` |
| **TC-AWS-04** | Amazon S3 Security Bucket  | 1. Chạy `aws s3 ls`.                                   | S3 Bucket tồn tại, có các folder prefix `reports/secrets/`, `reports/container/`, v.v. | Thành viên 1 | AWS CLI `aws s3 ls s3://<bucket-name>`  | `[ ] Pending` |

---

### Giai đoạn 2: Application & Containerization (Thành viên 4)

| Mã TC         | Hạng mục kiểm thử           | Các bước thực hiện                                                                                      | Kết quả mong đợi                                                                      | Người PT     | Phương pháp xác minh            | Trạng thái    |
| ------------- | --------------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- | ------------ | ------------------------------- | ------------- |
| **TC-APP-01** | React App Build             | 1. `cd app`<br>2. `npm install`<br>3. `npm run build`                                                   | Thư mục `app/build` được sinh ra không có lỗi fatal.                                  | Thành viên 4 | CLI output `npm run build`      | `[ ] Pending` |
| **TC-APP-02** | Local Docker Build & Health | 1. `docker build -t tetris:local -f app/Dockerfile app`<br>2. `docker run -d -p 8088:8080 tetris:local` | App phản hồi HTTP 200 OK tại `http://localhost:8088`. Non-root user `nginx`.          | Thành viên 4 | `curl -I http://localhost:8088` | `[ ] Pending` |
| **TC-APP-03** | Kubernetes Base Manifests   | 1. `kubectl kustomize kubernetes/overlays/staging`                                                      | Manifest render đúng container port 8080 và securityContext (non-root).               | Thành viên 4 | CLI output `kubectl kustomize`  | `[ ] Pending` |
| **TC-APP-04** | ECS Task Definition         | 1. Kiểm tra file `ecs-task-def.json`.                                                                   | Định nghĩa đúng ECR image URI, logConfiguration `awslogs`, CPU/Memory 0.25vCPU/512MB. | Thành viên 4 | File `ecs-task-def.json` review | `[ ] Pending` |

---

### Giai đoạn 3: DevSecOps Security Gates & Aggregator (Thành viên 3)

| Mã TC         | Hạng mục kiểm thử            | Các bước thực hiện                                                                 | Kết quả mong đợi                                                                    | Người PT     | Phương pháp xác minh                           | Trạng thái    |
| ------------- | ---------------------------- | ---------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | ------------ | ---------------------------------------------- | ------------- |
| **TC-SEC-01** | Secrets Scan (Gitleaks)      | 1. Cố tình thêm fake API key vào code.<br>2. Chạy `ci/stages/secrets-scan.sh`.     | Gitleaks phát hiện secret, xuất `gitleaks-report.json`, script trả về exit code 1.  | Thành viên 3 | Jenkins Build Fail log                         | `[ ] Pending` |
| **TC-SEC-02** | SCA Scan (Trivy FS)          | 1. Chạy `ci/stages/sca-scan.sh`.                                                   | Phân tích dependency `package.json`, xuất report HTML & JSON vào `scan-reports/`.   | Thành viên 3 | File `scan-reports/trivy-sca-report.json`      | `[ ] Pending` |
| **TC-SEC-03** | SAST Scan (SonarQube)        | 1. Khởi động SonarQube container.<br>2. Chạy `ci/stages/sast-scan.sh`.             | SonarQube phân tích source code, hiển thị dashboard bugs/vulnerabilities.           | Thành viên 3 | SonarQube UI Screenshot                        | `[ ] Pending` |
| **TC-SEC-04** | IaC Scan (Checkov)           | 1. Chạy `ci/stages/iac-scan.sh`.                                                   | Quét Kubernetes & Terraform manifests, xuất report `checkov_report.json`.           | Thành viên 3 | File `scan-reports/checkov_report.json`        | `[ ] Pending` |
| **TC-SEC-05** | Container Scan (Trivy Image) | 1. Chạy `ci/stages/container-scan.sh`.                                             | Quét Docker Image, lọc lỗ hổng CRITICAL/HIGH trước khi push ECR.                    | Thành viên 3 | File `scan-reports/container-scan-report.json` | `[ ] Pending` |
| **TC-SEC-06** | DAST Scan (OWASP ZAP)        | 1. Chạy `ci/stages/dast-scan.sh` trỏ vào Staging URL.                              | OWASP ZAP quét URL thật, xuất file `zap-report.html`.                               | Thành viên 3 | Open `zap-report.html` trên trình duyệt        | `[ ] Pending` |
| **TC-SEC-07** | S3 & Lambda Aggregator       | 1. Push file report JSON lên S3 bucket.<br>2. Kiểm tra CloudWatch logs của Lambda. | AWS Lambda tự động trigger, parse file report và ghi log tóm tắt lỗi High/Critical. | Thành viên 3 | CloudWatch Logs of Lambda function             | `[ ] Pending` |

---

### Giai đoạn 4: CI/CD Pipeline & ECR Integration (Thành viên 2)

| Mã TC          | Hạng mục kiểm thử           | Các bước thực hiện                                                 | Kết quả mong đợi                                                               | Người PT     | Phương pháp xác minh                                     | Trạng thái    |
| -------------- | --------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------ | ------------ | -------------------------------------------------------- | ------------- |
| **TC-CICD-01** | Jenkins Pipeline End-to-End | 1. Push code mới lên Git branch.<br>2. Quan sát Jenkins execution. | Tất cả các stage Security -> Build -> Test -> Scan chạy tuần tự thành công.    | Thành viên 2 | Jenkins Console Output Log                               | `[ ] Pending` |
| **TC-CICD-02** | Amazon ECR Image Push       | 1. Pipeline hoàn thành stage Push Image.                           | Image được tag theo Commit SHA và `latest`, xuất hiện trên Amazon ECR.         | Thành viên 2 | `aws ecr list-images --repository-name devsecops/tetris` | `[ ] Pending` |
| **TC-CICD-03** | Jenkins Artifact Archiving  | 1. Kiểm tra trang thông tin Jenkins Build vừa hoàn thành.          | Có đính kèm file nén/báo cáo security (`gitleaks`, `trivy`, `zap`, `checkov`). | Thành viên 2 | Jenkins UI Build Artifacts link                          | `[ ] Pending` |

---

### Giai đoạn 5: GitOps & ECS Deployment (Thành viên 2 & 4)

| Mã TC         | Hạng mục kiểm thử         | Các bước thực hiện                                                      | Kết quả mong đợi                                                          | Người PT     | Phương pháp xác minh                 | Trạng thái    |
| ------------- | ------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------- | ------------ | ------------------------------------ | ------------- |
| **TC-DEP-01** | Argo CD Staging Sync      | 1. Jenkins update tag mới vào repo GitOps.<br>2. Quan sát Argo CD UI.   | Argo CD tự động sync ứng dụng Staging về trạng thái `Synced` & `Healthy`. | Thành viên 2 | Argo CD Dashboard Screenshot         | `[ ] Pending` |
| **TC-DEP-02** | Staging App Accessibility | 1. Mở trình duyệt gõ URL ECS Staging ALB.                               | Giao diện Web React Tetris hiển thị bình thường, chơi thử game không lỗi. | Thành viên 4 | Trình duyệt Web Screenshot           | `[ ] Pending` |
| **TC-DEP-03** | Production Approval Gate  | 1. Quan sát Pipeline chờ tại Manual Approval Stage.                     | Pipeline KHÔNG tự động deploy lên Production khi chưa ấn Approval.        | Thành viên 2 | Jenkins Stage View UI                | `[ ] Pending` |
| **TC-DEP-04** | Production ECS Deployment | 1. Nhấn Approve trên Jenkins UI.<br>2. Kiểm tra ECS Production Service. | Task Production được cập nhật image mới, chạy ổn định với 2+ Replicas.    | Thành viên 4 | AWS ECS Console / ALB Production URL | `[ ] Pending` |

---

### Giai đoạn 6: Observability, CloudWatch & Monitoring (Thành viên 5)

| Mã TC         | Hạng mục kiểm thử             | Các bước thực hiện                                                                                                    | Kết quả mong đợi                                                                     | Người PT     | Phương pháp xác minh             | Trạng thái    |
| ------------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ------------ | -------------------------------- | ------------- |
| **TC-OBS-01** | CloudWatch Container Insights | 1. Mở CloudWatch Console -> Container Insights -> ECS Clusters.                                                       | Hiển thị biểu đồ CPU, Memory, Network Utilization của ECS Task Staging & Production. | Thành viên 5 | CloudWatch Console Screenshot    | `[x] PASS`    |
| **TC-OBS-02** | CloudWatch Log Groups         | 1. Vô CloudWatch -> Log Groups -> `/ecs/devsecops-factory/tetris-app`.                                                | Hiển thị đầy đủ stdout/stderr logs của container Nginx/React.                        | Thành viên 5 | CloudWatch Logs Screenshot       | `[ ] Pending` |
| **TC-OBS-03** | CloudWatch High CPU Alarm     | 1. Chạy script `ecs-cloudwatch-setup.ps1`.                                                                            | CloudWatch Alarm `ECS-Staging-High-CPU` được khởi tạo thành công ở trạng thái `OK`.  | Thành viên 5 | `aws cloudwatch describe-alarms` | `[x] PASS`    |
| **TC-OBS-04** | Local Prometheus Scrape       | 1. `docker compose -f monitoring/docker-compose.monitoring.yml up -d`<br>2. Truy cập `http://localhost:9090/targets`. | Scrape target Prometheus hiển thị `UP`.                                              | Thành viên 5 | Prometheus Web UI Screenshot     | `[x] PASS`    |
| **TC-OBS-05** | Grafana Dashboard Import      | 1. Truy cập `http://localhost:3000` (admin/admin123).                                                                 | Datasource Prometheus và Dashboard DevSecOps tự động được load.                      | Thành viên 5 | Grafana Dashboard UI Screenshot  | `[x] PASS`    |

---

### Giai đoạn 7: Deliverables, Workshop Website & Cleanup (Tất cả thành viên)

| Mã TC           | Hạng mục kiểm thử     | Các bước thực hiện                                                                                                                | Kết quả mong đợi                                                        | Người PT         | Phương pháp xác minh               | Trạng thái    |
| --------------- | --------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | ---------------- | ---------------------------------- | ------------- |
| **TC-DOC-01**   | Workshop Website FCAJ | 1. Mở trang Workshop Website.                                                                                                     | Có đầy đủ 8 mục bắt buộc, giao diện đẹp mắt, hỗ trợ **Song ngữ Vi/En**. | Thành viên 5     | Workshop Website UI Link           | `[ ] Pending` |
| **TC-DOC-02**   | 3 Blog Posts          | 1. Mở bài đăng trên AWS Study Group / Markdown files.                                                                             | Đủ 3 bài blog theo đúng phân công trong `tasks.md`.                     | TV1, 2, 3, 4, 5  | Link bài viết trên AWS Study Group | `[ ] Pending` |
| **TC-DOC-03**   | Demo Script 10 phút   | 1. Chạy diễn tập Demo theo kịch bản 12 bước.                                                                                      | Nhóm hoàn thành demo trong 10 phút, khớp từng bước, có ảnh backup.      | Thành viên 5     | Rehearsal Video / Timing           | `[ ] Pending` |
| **TC-CLEAN-01** | AWS Resource Cleanup  | 1. `aws ecs update-service --cluster devsecops-factory --service tetris-staging --desired-count 0`<br>2. Tắt ALB / S3 test files. | ECS Task scale về 0, không phát sinh chi phí AWS duy trì qua đêm.       | Thành viên 1 & 5 | AWS Billing / ECS Task count = 0   | `[ ] Pending` |

---

## 📸 Checklist Bộ Ảnh Bằng Chứng (Screenshots Required)

Các ảnh màn hình cần chụp lại để chèn vào **Workshop Website** và **Slide báo cáo**:

- [ ] **AWS-01**: Màn hình AWS Budget ($10/tháng) & Alert thresholds.
- [ ] **AWS-02**: Màn hình Amazon ECR Repository có chứa image tag theo commit SHA.
- [ ] **AWS-03**: Màn hình Amazon ECS Cluster (Staging & Production Tasks status = `RUNNING`).
- [ ] **SEC-01**: Log Gitleaks báo lỗi khi cố tình commit Secret.
- [ ] **SEC-02**: Báo cáo Trivy SCA Scan (HTML/JSON).
- [ ] **SEC-03**: Giao diện SonarQube Dashboard (Bugs, Code Smells, Coverage).
- [ ] **SEC-04**: Giao diện OWASP ZAP DAST Report (HTML).
- [ ] **SEC-05**: CloudWatch Log của **AWS Lambda Aggregator** đọc report từ S3.
- [ ] **CICD-01**: Giao diện Jenkins Pipeline Stage View xanh (Pass tất cả stages).
- [ ] **CICD-02**: Giao diện Argo CD UI trạng thái `Synced` & `Healthy`.
- [ ] **APP-01**: Giao diện Web Game Tetris chạy trên AWS ECS ALB Staging & Production.
- [ ] **OBS-01**: Biểu đồ CloudWatch Container Insights (CPU/Memory).
- [ ] **OBS-02**: CloudWatch Logs Insights query result.
- [ ] **OBS-03**: Grafana Dashboard hiển thị hệ thống monitoring.
