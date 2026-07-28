# CICD-03 - GitOps staging

## Yeu cau ban giao

- `cd/apps/staging.yaml` dung repository that.
- Jenkins cap nhat staging overlay bang image tag moi.
- Argo CD staging tu dong sync.
- Application co trang thai `Synced` va `Healthy`.
- Co anh Argo CD UI hoac output CLI.

## Phan code da san sang

- Application `tetris-staging` tro toi
  `https://github.com/loi-bui0703/FCAJ-final-project.git`.
- Revision `main`, path `kubernetes/overlays/staging`, namespace `staging`.
- Automated sync bat `prune`, `selfHeal`, `CreateNamespace=true` va retry.
- Stage 12 chi cap nhat GitOps tren release branch.
- `kustomize edit set image` dung immutable `${IMAGE_URI}`.
- Commit promotion co `[skip ci]` de tranh loop.
- Token duoc truyen qua temporary credential helper, khong ghi vao remote URL.

## Bang chung co the ban giao

- Manifest render:
  [`../evidence/kustomize-staging-rendered.yaml`](../evidence/kustomize-staging-rendered.yaml).
- Static checks:
  [`../evidence/static-validation.txt`](../evidence/static-validation.txt).

## Xac minh runtime con thieu

```bash
kubectl apply -f cd/apps/staging.yaml
kubectl -n argocd get application tetris-staging \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision
kubectl -n staging rollout status deployment/tetris-app --timeout=5m
kubectl -n staging get deployment tetris-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Dat khi output co `Synced`, `Healthy`, rollout thanh cong va image ket thuc bang
dung SHA vua duoc Jenkins push. Luu output vao
`../evidence/argocd-staging-status.txt` va anh vao
`../evidence/screenshots/task2-05-argocd-staging-healthy.png`.

Ket luan hien tai: **DAT PHAN MANIFEST/PIPELINE, CHO K3D HOAC EKS + ARGO CD**.
