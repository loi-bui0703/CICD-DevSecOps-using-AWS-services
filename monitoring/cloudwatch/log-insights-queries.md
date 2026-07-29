# CloudWatch Logs Insights Queries — Member 5 (Observability)

Sau đây là danh sách các câu lệnh truy vấn mẫu trên AWS CloudWatch Logs Insights dành cho Member 5 chạy và chụp ảnh báo cáo / workshop:

## 1. Truy vấn Nginx HTTP Status Summary (Đếm số request theo status code)

```sql
fields @timestamp, @message
| parse @message '* - - [*] "* * *" * *' as ip, datetime, method, request_path, protocol, status, bytes
| stats count(*) by status
| sort status asc
```

## 2. Tìm danh sách lỗi HTTP 4xx và 5xx

```sql
fields @timestamp, @message
| parse @message '* - - [*] "* * *" * *' as ip, datetime, method, request_path, protocol, status, bytes
| filter status >= 400
| sort @timestamp desc
| limit 50
```

## 3. Theo dõi số lượng log theo từng phút (Traffic Spike Analysis)

```sql
fields @timestamp
| stats count(*) by bin(1m)
| sort @timestamp desc
```

## 4. Kiểm tra Log từ AWS Lambda Security Aggregator

**Log Group**: `/aws/lambda/security-report-aggregator`

```sql
fields @timestamp, @message
| filter @message like /CRITICAL/ or @message like /HIGH/ or @message like /Report/
| sort @timestamp desc
| limit 20
```

## 5. Truy vấn Container Insights Logs (ECS Fargate Task Events)

**Log Group**: `/aws/ecs/containerinsights/devsecops-factory/performance`

```sql
fields @timestamp, TaskId, ContainerName, CpuUtilized, MemoryUtilized
| sort @timestamp desc
| limit 50
```
