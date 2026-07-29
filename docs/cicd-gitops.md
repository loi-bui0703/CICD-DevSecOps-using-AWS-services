# CI/CD và GitOps / CI/CD and GitOps

## Luồng phát hành

Pipeline trong `ci/Jenkinsfile` chạy trực tiếp trên monorepo hiện tại và dùng
commit SHA 12 ký tự làm image tag bất biến.

```text
checkout
  -> validate
  -> secrets / SCA / SAST / IaC
  -> Docker build
  -> container scan
  -> ECR push
  -> staging GitOps/ECS
  -> DAST
  -> normalize + ASFF
  -> S3 + Lambda/Security Hub
  -> manual approval
  -> production GitOps/ECS
```

## 22 stage

| # | Stage | Điều kiện |
|---:|---|---|
| 1 | Checkout Monorepo | Luôn chạy |
| 2 | Validate Inputs and Metadata | Bỏ qua commit `[skip ci]` |
| 3 | Security Contract | Ghi trạng thái script |
| 4–7 | Secrets, SCA, SAST, IaC | Theo `SECURITY_MODE`; SAST opt-in |
| 8 | Build Docker Image | Tag SHA và `latest` local |
| 9 | Container Scan | Theo `SECURITY_MODE` |
| 10–11 | ECR Login, Push | Login khi dùng ECR |
| 12 | Local GitOps image mirror | Mirror image đã scan cho k3d |
| 13–14 | GitOps/ECS Staging | Chỉ release branch và opt-in |
| 15 | DAST Staging | Cần URL staging |
| 16 | Normalize Reports | Tạo schema chung và summary |
| 17 | Generate Security Hub ASFF | Opt-in |
| 18 | Upload Reports to S3 | Opt-in |
| 19 | Production Approval | Manual gate, có timeout |
| 20–21 | GitOps/ECS Production | Chỉ sau approval |
| 22 | Summary | Tóm tắt build |

## Chế độ bảo mật

| Mode | Hành vi |
|---|---|
| `stub` | Không chạy scanner; phù hợp kiểm tra pipeline/local registry |
| `report-only` | Scanner lỗi làm stage `UNSTABLE`, pipeline tiếp tục |
| `enforce` | Scanner/report lỗi chặn pipeline; bắt buộc khi promote production |

`SECURITY_BLOCK_SEVERITIES` mặc định là `CRITICAL`. Trong `enforce`, Trivy SCA
và container scan chặn khi JSON report chứa severity này; SonarQube chờ Quality
Gate và ZAP chặn khi có alert. Có thể dùng danh sách như `CRITICAL,HIGH`.

Các script ghi raw reports vào `scan-reports/raw/<category>/`. Stage normalize
tạo `scan-reports/normalized/findings.json` và `summary.json`. Nếu bật Security
Hub, ASFF được tạo tại `scan-reports/asff/securityhub-asff.json`.

## AWS và credentials

Ưu tiên `AWS_AUTH_MODE=default-chain` với IAM role, AWS SSO/profile hoặc biến
môi trường được inject tại runtime. `jenkins-credentials` dùng credential ID
`aws-credentials`, trong đó username là access key ID và password là secret key.

| Credential ID | Kiểu | Mục đích |
|---|---|---|
| `aws-credentials` | Username/password | AWS local fallback |
| `github-token` | Username/password | Commit GitOps overlay |
| `sonar-token` | Secret text | SonarQube |

Không commit secret vào `.env`, JCasC, task definition hoặc Git remote URL.

## GitOps

Jenkins clone repository GitOps vào workspace riêng, chạy:

```bash
kustomize edit set image "tetris-devsecops=${IMAGE_URI}"
```

Commit có hậu tố `[skip ci]` để tránh vòng lặp. Staging và production đều nhận
đúng SHA image đã scan. Production chỉ cập nhật sau manual approval.

Demo local dùng Git daemon chỉ lắng nghe trên loopback của máy host và network
Docker `devsecops`. `make gitops-seed` tạo branch nguồn; Jenkins push commit
GitOps vào remote này, còn Argo CD trong k3d đọc qua
`git://gitops-git-server:9418/devsecops.git`. Image ECR đã scan được mirror vào
local registry, nhưng Kustomize vẫn giữ cùng immutable SHA tag.

## ECS

Terraform tạo cluster `devsecops-factory-cluster`, services `tetris-staging` và
`tetris-production`, task family `tetris-app`. Jenkins đọc revision hiện tại,
chỉ thay image, register revision mới, update desired count và đợi service
stable. Terraform bỏ qua thay đổi `desired_count`/`task_definition` sau khi tạo
để không giành quyền điều khiển với pipeline.

## English

The pipeline uses one monorepo and one immutable commit-based image tag.
Cloud/GitOps actions are opt-in, production is fail-closed behind
`SECURITY_MODE=enforce` and manual approval, and report normalization produces a
single schema before optional S3/Lambda/Security Hub ingestion.
