# Vulnerability & Security Findings — Tetris React App

Tài liệu này ghi lại các vulnerability được phát hiện trong quá trình DevSecOps scan.
Mục đích: cung cấp dữ liệu demo cho security pipeline (SCA, Container Scan, SAST).

---

## 1. SCA — Dependency Vulnerabilities (`npm audit`)

**Tool:** Trivy filesystem / `npm audit`
**Kết quả sau khi nâng build tool và bỏ `gh-pages`:** 71 vulnerabilities tổng cộng

| Severity | Số lượng |
|---|---|
| Critical | 0 |
| High | 62 |
| Moderate | 5 |
| Low | 4 |

### Các dependency cũ chính gây findings

| Package | Phiên bản hiện tại | Vấn đề |
|---|---|---|
| `react` | 16.12.0 | EOL — React 16 không còn nhận security patch |
| `react-dom` | 16.12.0 | EOL |
| `react-scripts` | 5.0.1 | CRA đã maintenance mode; nên migrate sang Vite |
| `core-js` | 2.6.11 / 3.6.4 | Deprecated, gây slowdown tới 100x theo V8 |
| `eslint` | 6.8.0 | EOL — không còn security support |
| `debug` | 3.2.6 | CVE: ReDoS regression (nên dùng ≥3.2.7) |
| `styled-components` | 5.0.1 | Phiên bản cũ, có prototype pollution risk |
| `react-spring` | 8.0.27 | Phiên bản cũ |
| `babel-eslint` | 10.0.3 | Deprecated (đổi sang `@babel/eslint-parser`) |
| `svgo` | 1.3.2 | Deprecated, nên dùng v2.x |
| `rimraf` | 2.x | EOL (nên dùng v4+) |

### Trạng thái còn lại

Logic ứng dụng gốc vẫn dùng một số dependency cũ. Các finding còn lại được giữ
lại có chủ đích cho bài lab:
- Tạo SCA findings thật cho pipeline demo
- Minh hoạ security gate khi có CRITICAL vulnerability
- Cho phép Thành viên 3 demo Trivy filesystem scan với kết quả thực tế

> **Không nên dùng cấu hình này trong production thật.**

---

## 2. Container Scan — Base Image Vulnerabilities

**Tool:** Trivy image scan
**Image:** `node:22-alpine` (build stage) + `nginxinc/nginx-unprivileged:alpine` (runtime)

### Node.js 22 (build stage)

| Vấn đề | Mô tả |
|---|---|
| Legacy toolchain | Build runtime còn được hỗ trợ nhưng Create React App và dependency frontend vẫn cần được thay thế trước production thật |

> Build stage không đưa vào runtime image — chỉ ảnh hưởng đến CI build environment.

### nginxinc/nginx-unprivileged:alpine (runtime)

| Điểm tích cực | Ghi chú |
|---|---|
| Non-root user | Chạy với user nginx (uid 101) — không phải root ✅ |
| Port 8080 | Không dùng port 80 đặc quyền ✅ |
| Alpine base | Image nhỏ, ít attack surface ✅ |

| Rủi ro còn lại | Ghi chú |
|---|---|
| Alpine CVE | Có thể có CVE trong musl libc hoặc busybox tùy version |
| Nginx version | Phụ thuộc tag image; nên pin version cụ thể thay vì `alpine` |

---

## 3. IaC Scan — Kubernetes Manifests (Checkov)

**Tool:** Checkov
**Files scanned:** `kubernetes/`, `docker-compose*.yml`

| Finding | File | Mức độ | Trạng thái |
|---|---|---|---|
| `readOnlyRootFilesystem: true` thiếu volume | `base/deployment.yaml` | Medium | ✅ Fixed (thêm emptyDir volumes cho Nginx) |
| `runAsNonRoot: true` | `base/deployment.yaml` | Compliant | ✅ |
| `allowPrivilegeEscalation: false` | `base/deployment.yaml` | Compliant | ✅ |
| `capabilities.drop: ALL` | `base/deployment.yaml` | Compliant | ✅ |
| No resource limits | `base/deployment.yaml` | Compliant | ✅ (đã có limits) |
| No liveness/readiness probe | `base/deployment.yaml` | Compliant | ✅ (đã có probes) |

---

## 4. Compatibility Issue — Node.js OpenSSL

**Phát hiện cũ:** `ERR_OSSL_EVP_UNSUPPORTED` khi chạy `react-scripts@3.4.0`
với Node.js dùng OpenSSL 3.

**Nguyên nhân:**
- `react-scripts@3.4.0` (năm 2020) dùng **webpack 4** gọi thuật toán hash MD4
- Node.js v17+ nâng lên **OpenSSL 3** — loại bỏ MD4 → build crash

**Error message:**
```
Error: error:0308010C:digital envelope routines::unsupported
code: 'ERR_OSSL_EVP_UNSUPPORTED'
Node.js v22.12.0
```

**Fix đã áp dụng:**
Không hạ Node.js xuống bản EOL và không bật legacy crypto provider. Build tool
đã được nâng lên `react-scripts@5.0.1`:
```bash
npm run build
```

**Kết quả sau fix:**
```
Compiled successfully.
  70.67 KB  build/static/js/2.ca2f7e3c.chunk.js
  5.21 KB   build/static/js/main.ee726c3e.chunk.js
```

**Trong Dockerfile:** Dùng `node:22-alpine`; runtime chỉ chứa Nginx.

---

## 5. Demo Scenarios cho Security Pipeline

### Scenario 1 — SCA Gate (Trivy filesystem)

```bash
# Scan kiểm tra các dependency còn lại
trivy fs --exit-code 1 --severity CRITICAL ./app
```
Kỳ vọng hiện tại: **FAIL** nếu finding critical còn tồn tại; xem JSON report để
xác nhận package và fixed version thay vì dựa vào số lượng cố định.

### Scenario 2 — Container Scan Gate (Trivy image)

```bash
# Scan image runtime và build artifacts
trivy image --exit-code 1 --severity CRITICAL devsecops/tetris:local
```
Kỳ vọng: Trivy báo các CVE còn tồn tại trong dependency hoặc Alpine packages.

### Scenario 3 — Build Compatibility Gate

Nếu Jenkins agent dùng Node 18+ mà không set `NODE_OPTIONS`:
- Build sẽ **fail** với `ERR_OSSL_EVP_UNSUPPORTED`
- Pipeline phải bắt lỗi này và báo rõ nguyên nhân

---

## 6. Đề xuất Remediation (không áp dụng trong demo)

| Vấn đề | Giải pháp đề xuất |
|---|---|
| React 16 EOL | Upgrade lên React 18 + react-scripts 5.x |
| Legacy CRA/Webpack | Migrate sang Vite và bỏ `--openssl-legacy-provider` |
| 227 npm vulnerabilities | Chạy `npm audit fix --force` sau khi test tương thích |
| Webpack 4 OpenSSL | Upgrade react-scripts hoặc migrate sang Vite |
| Pinned image tags | Dùng digest thay vì tag (ví dụ: `nginx@sha256:...`) |
