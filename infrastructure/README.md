# AWS & Kubernetes Infrastructure Guide (Hướng dẫn Hạ tầng AWS & Kubernetes)

Tài liệu này chứa hướng dẫn chi tiết về cấu trúc hạ tầng local và cloud cho dự án DevSecOps, thuộc phạm vi trách nhiệm của **Thành viên 1**.

This document contains a detailed guide on the local and cloud infrastructure configuration for the DevSecOps project, managed by **Member 1**.

---

## Tiếng Việt (Vietnamese)

### 1. Chuẩn hóa Mạng Local (k3d)
Tệp `infrastructure/k3d/cluster.yaml` đã được cập nhật để sử dụng chung mạng Docker với Docker Compose:
- **Tên mạng Docker:** `devsecops` (Đồng nhất với cấu hình trong `docker-compose.yml` để đảm bảo kết nối nội bộ mượt mà).

Để khởi động cụm k3d local và đăng ký local registry:
```bash
# Đảm bảo Registry đã chạy thông qua docker compose
docker compose -f docker-compose.infra.yml up -d

# Tạo cụm k3d
k3d cluster create --config infrastructure/k3d/cluster.yaml
```

### 2. Thiết lập AWS Cloud Foundation bằng Terraform
Thư mục `infrastructure/terraform` chứa mã nguồn IaC để tự động hóa toàn bộ hạ tầng AWS:

#### Tài nguyên được tạo lập:
1. **AWS-01 (Budget & IAM):**
   - Thiết lập Budget $50/tháng với các mốc cảnh báo email (50%, 80%, 100%) tránh vượt chi phí.
   - IAM Task/Execution Roles cho ECS Fargate với quyền kéo ECR và đẩy log lên CloudWatch.
2. **AWS-02 (Amazon ECR):**
   - Tạo Private Repository `devsecops/tetris` có bật quét bảo mật tự động `scan_on_push`.
3. **AWS-03 (ECS Fargate Cluster):**
   - ECS Cluster `devsecops-factory-cluster` bật CloudWatch Container Insights.
   - Sử dụng **Fargate Capacity Providers** với cấu hình ưu tiên `FARGATE_SPOT` để tiết kiệm tới 70% chi phí.
   - Hai dịch vụ ECS Service: `tetris-staging` (1 replica) và `tetris-production` (2 replicas).
   - Hai Application Load Balancer (ALB) riêng biệt để định tuyến cho Staging và Production.
4. **AWS-04 (S3 Bucket lưu Security Reports):**
   - Tạo S3 Bucket `devsecops-reports-<random-suffix>`.
   - Bật Versioning để theo dõi lịch sử báo cáo.
   - Mã hóa dữ liệu tĩnh (SSE-S3) và chặn toàn bộ truy cập công khai.
   - Lifecycle policy tự động xóa các report cũ sau 30 ngày.
   - Định dạng thư mục (prefixes):
     - `reports/secrets/` (Gitleaks reports)
     - `reports/sca/` (Trivy Filesystem reports)
     - `reports/sast/` (SonarQube/Semgrep reports)
     - `reports/container/` (Trivy Image reports)
     - `reports/dast/` (OWASP ZAP reports)

#### Các bước khởi tạo bằng Terraform:
1. Tạo tệp cấu hình tham số:
   ```bash
   cd infrastructure/terraform
   cp terraform.tfvars.example terraform.tfvars
   # Mở file terraform.tfvars điền email nhận cảnh báo budget
   ```
2. Khởi tạo và apply:
   ```bash
   terraform init
   terraform validate
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

### 3. Đăng nhập Docker vào ECR
Sau khi tạo ECR, để đẩy ảnh từ Jenkins hoặc máy local lên registry:
```bash
# Đăng nhập AWS CLI (nếu chạy local)
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com
```

### 4. Quy trình Cleanup để tránh chi phí ngoài mong muốn
> [!WARNING]
> Luôn dọn dẹp tài nguyên hoặc scale dịch vụ về 0 khi không chạy demo để tránh phát sinh chi phí AWS ngoài dự kiến.

#### Cách 1: Scale các ECS Services về 0 (Khuyên dùng khi cần giữ lại hạ tầng để demo tiếp)
Chạy lệnh sau để tạm ngưng các task Fargate đang chạy (tránh trả phí cho CPU/Memory):
```bash
# Staging scale to 0
aws ecs update-service --cluster devsecops-factory-cluster --service tetris-staging --desired-count 0 --region ap-southeast-1

# Production scale to 0
aws ecs update-service --cluster devsecops-factory-cluster --service tetris-production --desired-count 0 --region ap-southeast-1
```
Khi cần demo lại, chỉ cần update desired-count về `1` (Staging) hoặc `2` (Production).

#### Cách 2: Phá hủy toàn bộ tài nguyên cloud (Khi kết thúc học kỳ/dự án)
```bash
cd infrastructure/terraform
terraform destroy -auto-approve
```

---

## English (Tiếng Anh)

### 1. Local Network Standardization (k3d)
The `infrastructure/k3d/cluster.yaml` has been configured to use the same Docker network as Docker Compose:
- **Docker Network Name:** `devsecops` (Unified to allow smooth container-to-container communication).

To spin up the local k3d cluster with the local registry mirror:
```bash
# Ensure local registry is running via docker-compose
docker compose -f docker-compose.infra.yml up -d

# Create the cluster
k3d cluster create --config infrastructure/k3d/cluster.yaml
```

### 2. Provisioning AWS Cloud Foundation with Terraform
The `infrastructure/terraform` folder contains the IaC code to spin up the cloud environment:

#### Resources provisioned:
1. **AWS-01 (Budget & IAM):**
   - Monthly budget limit set to $50 with alert threshold notifications (50%, 80%, 100%) to avoid billing surprises.
   - ECS Task/Execution Roles with permissions to pull ECR images and publish logs to CloudWatch.
2. **AWS-02 (Amazon ECR):**
   - Private repository `devsecops/tetris` with `scan_on_push` enabled for vulnerability analysis.
3. **AWS-03 (ECS Fargate Cluster):**
   - ECS cluster named `devsecops-factory-cluster` with CloudWatch Container Insights enabled.
   - Configured with Fargate Capacity Providers mapping to `FARGATE_SPOT` to save up to 70% in compute costs.
   - Two ECS Fargate services: `tetris-staging` (1 task) and `tetris-production` (2 tasks).
   - Independent public ALBs for Staging and Production.
4. **AWS-04 (Amazon S3 Security Reports Bucket):**
   - S3 Bucket `devsecops-reports-<random-suffix>` with versioning enabled.
   - SSE-S3 encryption and public access blocking enabled.
   - Lifecycle policy to auto-expire files after 30 days.
   - Directory structures (prefixes):
     - `reports/secrets/` (Gitleaks reports)
     - `reports/sca/` (Trivy Filesystem reports)
     - `reports/sast/` (SonarQube/Semgrep reports)
     - `reports/container/` (Trivy Image reports)
     - `reports/dast/` (OWASP ZAP reports)

#### Execution Steps:
1. Configure variables:
   ```bash
   cd infrastructure/terraform
   cp terraform.tfvars.example terraform.tfvars
   # Open terraform.tfvars and put your alert email
   ```
2. Initialize and deploy:
   ```bash
   terraform init
   terraform validate
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

### 3. Docker ECR Authenticate
Once ECR is provisioned, log in your local Docker daemon to AWS ECR:
```bash
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com
```

### 4. Cleanup Instructions (AWS Cost Savings)
> [!WARNING]
> ECS tasks charge per second. Always scale services to 0 or tear down the stack when not demoing.

#### Option 1: Scale ECS Fargate services to 0 (Recommended during semester/active phase)
To pause compute charges while keeping configuration, scale tasks down to 0:
```bash
# Staging scale to 0
aws ecs update-service --cluster devsecops-factory-cluster --service tetris-staging --desired-count 0 --region ap-southeast-1

# Production scale to 0
aws ecs update-service --cluster devsecops-factory-cluster --service tetris-production --desired-count 0 --region ap-southeast-1
```
When ready to demo again, scale desired count back to `1` or `2`.

#### Option 2: Destroy the whole AWS cloud infrastructure (At the end of project)
```bash
cd infrastructure/terraform
terraform destroy -auto-approve
```
