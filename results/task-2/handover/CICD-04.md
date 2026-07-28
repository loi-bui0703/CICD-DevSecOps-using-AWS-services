# CICD-04 - GitOps production

## Yeu cau ban giao

- Production Argo CD Application chay duoc.
- Namespace `production`, overlay `kubernetes/overlays/production`.
- Jenkins co manual approval gate.
- Co quy trinh promote staging sang production.
- Khong deploy production truoc approval.

## Phan code da san sang

- `tetris-production` dung repo/revision giong staging, path production va
  namespace `production`.
- Stage 2 fail-closed: production bat buoc co deploy target va
  `SECURITY_MODE=enforce`.
- Stage 16 dung Jenkins `input` va timeout 1..1440 phut.
- Co the gioi han approver bang `PRODUCTION_APPROVERS`.
- Stage 17/18 nam sau approval va dung lai chinh `${IMAGE_URI}` da build/scan.
- Production overlay render voi 3 replicas.

## Bang chung co the ban giao

- Manifest render:
  [`../evidence/kustomize-production-rendered.yaml`](../evidence/kustomize-production-rendered.yaml).
- Jenkinsfile linter:
  [`../evidence/jenkinsfile-linter.txt`](../evidence/jenkinsfile-linter.txt).
- Static checks ve gate:
  [`../evidence/static-validation.txt`](../evidence/static-validation.txt).

## Gioi han hien tai

Chua the tao mot build dung tai manual gate mot cach hop le vi production bat
buoc `SECURITY_MODE=enforce`, trong khi `ci/stages/secrets-scan.sh` dang rong.
Bo qua security de chup anh se trai voi fail-closed policy va khong duoc tinh
la bang chung dat.

## Danh gia runtime sau khi co dependency

1. Chay build tren release branch voi `SECURITY_MODE=enforce`,
   `PROMOTE_PRODUCTION=true` va it nhat mot deploy target.
2. Xac nhan build dung o `16. Production Approval`; production image chua doi.
3. Chup `task2-06-production-approval.png`.
4. Tu choi mot build va xac nhan stage 17/18 khong chay.
5. Chay lai, chap thuan va doi rollout/Argo CD healthy.
6. Xac nhan staging va production dung cung immutable image digest/SHA.
7. Chup `task2-07-production-result.png`.

Ket luan hien tai: **DAT PHAN CODE, CHO SECURITY CONTRACT VA PRODUCTION RUNTIME**.
