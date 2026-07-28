# Kết quả tích hợp Task 1–4

Ngày kiểm tra: `2026-07-28`
Branch đích: `cicd-gitops` trong thư mục `task-2`

## Đã xác minh

| Kiểm tra | Kết quả |
|---|---|
| Merge lịch sử `aws-infra`, `task-3`, `hao_feat_task4` | PASS |
| Python unit test normalize report → ASFF | PASS |
| Jenkins Declarative Pipeline linter | PASS |
| Terraform `fmt -check` và `validate` | PASS |
| Kustomize staging/production render | PASS |
| Docker Compose infra/security/observability/root config | PASS |
| Prometheus config và alert rules bằng `promtool` | PASS |
| Blackbox Exporter config check | PASS |
| `npm ci` và React production build | PASS |
| Docker multi-stage application image build | PASS |
| HTTP/Docker health smoke test | PASS |
| Hardened smoke test: UID 101 + read-only root + tmpfs | PASS |
| Obvious AWS/GitHub/private-key pattern scan | PASS |

## Security dependency baseline

Sau khi nâng `react-scripts` và bỏ `gh-pages`/TypeScript không dùng:

```text
71 vulnerabilities: 4 low, 5 moderate, 62 high, 0 critical
```

Các finding còn lại chủ yếu nằm trong toolchain Create React App đã maintenance
mode. Xem `app/VULNERABILITIES.md`; migrate sang Vite là remediation tiếp theo
cho production thật.

## Chưa thể xác minh live

`aws sts get-caller-identity` trả về `NoCredentials`; `aws configure
list-profiles` không có profile và không tìm thấy `.env` trong bốn thư mục.
Vì vậy chưa chạy `terraform plan/apply`, push ECR, ECS/ALB live, S3 trigger hoặc
Security Hub live. Không có resource AWS nào được tạo bởi lần tích hợp này.
