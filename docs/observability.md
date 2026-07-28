# Observability / Quan sát hệ thống

## Local

`docker-compose.obs.yml` chạy:

- Prometheus lưu metric 7 ngày.
- Blackbox Exporter kiểm tra Jenkins, Registry, SonarQube và Tetris staging.
- Grafana tự provision Prometheus datasource và dashboard availability.
- Alert `DevSecOpsServiceUnavailable` kích hoạt sau hai phút probe lỗi.

```bash
make up-obs
docker compose -f docker-compose.obs.yml ps
```

Validate cấu hình:

```bash
docker compose -f docker-compose.obs.yml config --quiet
```

Prometheus: <http://localhost:9090>
Grafana: <http://localhost:3000>

Tetris probe dùng `host.docker.internal` với HTTP Host
`tetris-staging.localhost`. Trên Linux, Compose thêm host-gateway tự động.

## AWS

Terraform bật ECS Container Insights và đưa stdout/stderr của container vào
CloudWatch log group `/ecs/devsecops-factory`, retention 7 ngày. Lambda importer
có log group riêng retention 7 ngày.

Kiểm tra sau deploy:

```bash
aws logs tail /ecs/devsecops-factory --follow --region ap-southeast-1
aws ecs describe-services \
  --cluster devsecops-factory-cluster \
  --services tetris-staging tetris-production \
  --region ap-southeast-1
```

## English

Local observability uses Prometheus, Grafana, and Blackbox Exporter. AWS
observability uses ECS Container Insights and CloudWatch Logs with seven-day
retention.
