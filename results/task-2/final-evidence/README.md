# Task 2 technical evidence

Collected on 2026-07-29. This directory contains runtime evidence only; it is
not the workshop report.

## Verified outcomes

- Terraform created the AWS environment and the final plan reports
  `No changes. Your infrastructure matches the configuration.`
- Jenkins `FULL_PROJECT_DEMO` build `#2` completed with `SUCCESS` across all
  22 stages, including the authenticated production approval.
- The same immutable image tag `1dba575f066c` was promoted through ECR, ECS
  staging, GitOps staging, GitOps production, and ECS production.
- Jenkins archived 33 security/deployment artifacts. The normalized report
  contains 186 findings and no expected scanner report is missing.
- S3 contains the uploaded scan reports. Security Hub contains 186 imported
  findings. CloudWatch reports one Lambda importer invocation and zero errors.
- Both AWS ECS services were returned to `desired=0`, `running=0`,
  `pending=0` after verification.
- Both local Argo CD applications are `Synced` and `Healthy` at commit
  `cce79689770fd0d1881738df52a3cb9ad7899fcc`.
- Prometheus reported every configured target `UP`; Grafana displayed all
  service-availability values as `1`.

## Main evidence

- `logs/jenkins-build-2-console.log` — complete Jenkins console.
- `logs/jenkins-build-2-stages.json` — machine-readable stage status.
- `logs/jenkins-production-approval-dom.txt` — manual approval prompt.
- `logs/jenkins-build-2-success-dom.txt` — build success and approval record.
- `jenkins-artifacts/build-2/` — all archived security/deployment artifacts.
- `aws/terraform-final-plan.txt` — final zero-drift Terraform plan.
- `aws/ecs-services-after-promotion.json` — deployed ECS state before reset.
- `aws/ecs-services-final-zero.json` — cost-safe ECS state after reset.
- `aws/s3-security-reports.json` — uploaded security report objects.
- `aws/securityhub-imported-findings.json` — imported Security Hub findings.
- `aws/lambda-invocations-metric.json` and `aws/lambda-errors-metric.json` —
  Lambda execution metrics.
- `logs/argocd-applications-final.txt` — final Argo CD status and revision.
- `logs/prometheus-targets-final.json` — all active Prometheus targets.

## Screenshots

- `screenshots/tetris-staging-full-window.png`
- `screenshots/tetris-production-full-window.png`
- `screenshots/tetris-production-game-full-window.png`
- `screenshots/prometheus-all-targets-up-full-window.png`
- `screenshots/prometheus-all-targets-up-full-page.png`
- `screenshots/grafana-service-availability-full-page.png`
- `screenshots/cloudwatch-lambda-metrics-full-window.png`
- `screenshots/argocd-summary-synced-healthy-full-page.png`
- `screenshots/sonarqube-quality-gate-full-page.png`

Secrets, Terraform state, access keys, and local `.env` values are excluded.
