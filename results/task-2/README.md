# Ban giao Task 2 - CI/CD va GitOps

Ngay chot bang chung: `2026-07-23`
Branch: `cicd-gitops`

Day la goi ban giao doi chieu truc tiep voi phan **Task 2** trong
`tasks.md`. Trang thai chi duoc danh dau `DAT` khi co code va bang chung kiem
thu tuong ung; cac tich hop can tai nguyen that khong duoc suy dien tu manifest.

## Ket luan nhanh

| Ma | Yeu cau ban giao trong `tasks.md` | Trang thai | Ho so |
|---|---|---|---|
| CICD-01 | Jenkinsfile build duoc image, log ro, archive security artifacts | **DAT - local** | [CICD-01](handover/CICD-01.md) |
| CICD-02 | ECR co SHA tag va anh chup repository | **CHO DAU VAO** | [CICD-02](handover/CICD-02.md) |
| CICD-03 | Argo CD staging `Synced`/`Healthy` va anh UI/CLI | **DAT PHAN CODE, CHO RUNTIME** | [CICD-03](handover/CICD-03.md) |
| CICD-04 | Production app, manual approval, quy trinh promote | **DAT PHAN CODE, CHO RUNTIME** | [CICD-04](handover/CICD-04.md) |
| CICD-05 | Bang credentials, khong hardcode token | **DAT** | [CICD-05](handover/CICD-05.md) |

## Pham vi co the ban giao ngay

1. Pipeline local tu checkout den build va push image bang commit SHA.
2. Log pipeline, metadata va security integration status duoc archive.
3. Security `enforce` fail som, thong bao ro khi script bat buoc chua san sang.
4. Parameter ECR sai fail truoc khi login/build/push.
5. Argo CD Application staging va production, dung overlay/namespace.
6. Manual approval gate va co che promote cung immutable image sang production.
7. Bang credential ID, cach cap secret va kiem tra mau secret pho bien.

## Lan chay bang chung

Jenkins tam duoc khoi tao bang JCasC tren `2026-07-23`, dung source snapshot
`bc0bc4f4760ad80a29236029e9b2433d91ee5e13`:

| Build | Ket qua mong doi | Ket qua thuc te |
|---|---|---|
| `#1` | Local registry + `SECURITY_MODE=stub` chay het pipeline | `SUCCESS`, image tag `bc0bc4f4760a` |
| `#2` | `SECURITY_MODE=enforce` fail khi secrets script rong | `FAILURE`, Docker build bi skip |
| `#3` | ECR target rong fail truoc side effect | `FAILURE`, bao `ECR_REGISTRY is required.` |

Hai container bang chung da duoc dung sau khi chup anh; khong sua/xoa Jenkins
volume, image hay container cu cua nguoi dung.

## Pham vi chua duoc phep ket luan da dat

- ECR push that va screenshot ECR: thieu ECR URI/IAM cua Thanh vien 1.
- Argo CD staging/production runtime: may hien tai khong co `k3d`, khong co
  Kubernetes context va chua co Argo CD de tao trang thai `Synced`/`Healthy`.
- Production promotion end-to-end: `secrets-scan.sh` dang rong, trong khi
  production bat buoc `SECURITY_MODE=enforce`.
- ECS/S3: thieu resource ID va IAM that.

Chi tiet dau vao can nguoi dung/nhom cung cap nam tai
[Ho tro can thiet](ASSISTANCE-REQUIRED.md).

## Cau truc bang chung

- `handover/`: yeu cau, code dap ung, bang chung va tieu chi danh gia tung ma.
- `evidence/`: output kiem thu, manifest render, artifact va anh chup.
- `scripts/verify-handover.sh`: chay lai cac kiem tra tinh tai may bat ky.
- Tai lieu hien thuc va kiem thu day du:
  [`../../docs/cicd-gitops.md`](../../docs/cicd-gitops.md).

## Chay lai kiem tra tinh

Tu thu muc goc repository:

```bash
bash results/task-2/scripts/verify-handover.sh
```

Ket qua duoc ghi vao `results/task-2/evidence/static-validation.txt` va hai file
Kustomize render. Tat ca dong trong phan `SUMMARY` phai la `PASS`.
