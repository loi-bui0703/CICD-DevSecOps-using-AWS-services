# Hạ tầng AWS và k3d / AWS and k3d Infrastructure

## Local k3d

Compose và k3d dùng chung Docker network `devsecops`. Local registry chạy tại
host `localhost:5001` và tại container DNS `local-registry:5000`.

```bash
make network-create
make up-infra
make k3d-create
make k3d-configure
make argocd-install
```

## Terraform

`infrastructure/terraform` quản lý:

- AWS Budget với cảnh báo 50/80/100%.
- IAM execution/task roles và policy tối thiểu cho Jenkins.
- ECR `devsecops/tetris`, scan on push và mã hóa AES-256.
- S3 report bucket: private, encrypted, versioned, lifecycle 30 ngày.
- VPC, hai public subnet, security groups và hai ALB.
- ECS Fargate cluster có Container Insights, staging trên Fargate Spot,
  production trên Fargate.
- CloudWatch log group retention 7 ngày.
- Lambda S3 → Security Hub tùy chọn.

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

Các output quan trọng:

| Output | Dùng ở đâu |
|---|---|
| `ecr_repository_url` | Jenkins `ECR_REGISTRY` + `IMAGE_REPOSITORY` |
| `s3_bucket_name` | `SECURITY_REPORT_BUCKET` |
| `ecs_cluster_name` | `ECS_CLUSTER` |
| `ecs_task_family` | Hai ECS task-family parameters |
| `alb_dns_staging` | `STAGING_URL` cho DAST |
| `jenkins_ci_policy_arn` | Attach vào IAM role/user chạy Jenkins |

## Lambda / Security Hub

Mặc định `enable_security_hub_importer=false`. Khi bật, Terraform:

1. Bật Security Hub trong region.
2. Đóng gói `infrastructure/lambda/securityhub-importer/lambda_function.py`.
3. Tạo role chỉ có S3 GetObject, Security Hub BatchImportFindings và log.
4. Trigger Lambda khi có
   `reports/asff/.../securityhub-asff.json`.

## Chi phí và cleanup

Task count mặc định là `0`. Dùng `scripts/scale-ecs.sh up|down` khi demo.

> Hai ALB vẫn tính phí khi ECS ở mức 0. Scale-down không thay thế Terraform
> destroy.

```bash
CONFIRM_AWS_CLEANUP=devsecops-factory scripts/cleanup-aws.sh
CONFIRM_AWS_CLEANUP=devsecops-factory DESTROY_TERRAFORM=true scripts/cleanup-aws.sh
```

## English

Terraform provisions the project foundation and starts both ECS services at
zero tasks. Jenkins owns later task-definition and desired-count changes.
Security Hub ingestion is explicitly opt-in. Review the plan and destroy ALBs
after demos because scaling ECS to zero does not stop all AWS charges.
