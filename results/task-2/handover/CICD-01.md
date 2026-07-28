# CICD-01 - Jenkins pipeline

## Yeu cau ban giao

- Jenkinsfile chay duoc toi buoc build image.
- Log pipeline ro rang.
- Security report duoc archive.
- Mot build local/AWS chay end-to-end.
- Security failure phai co thong bao de hieu.

## Hien thuc dap ung

- Pipeline dung chinh monorepo, khong checkout `target-repo`.
- Image tag la 12 ky tu dau cua commit SHA.
- Stage 8 build ca immutable tag va `latest`; stage 11 push immutable tag.
- Stage 3 tao `security-integration-status.txt`.
- `post/always` archive `scan-reports/**/*`, ke ca khi pipeline fail.
- `SECURITY_MODE` co ba che do: `stub`, `report-only`, `enforce`.
- Trong `enforce`, script rong/mat hoac report bat buoc khong duoc tao se fail
  voi ten scanner va duong dan ro rang.

## Bang chung

| Bang chung | Y nghia |
|---|---|
| [`../evidence/jenkins-build-success.log`](../evidence/jenkins-build-success.log) | Build local thanh cong, commit SHA, image URI va stage ket thuc. |
| [`../evidence/jenkins-security-enforce-failure.log`](../evidence/jenkins-security-enforce-failure.log) | Negative test fail tai security contract, build image bi skip. |
| [`../evidence/jenkins-ecr-parameter-failure.log`](../evidence/jenkins-ecr-parameter-failure.log) | ECR parameter rong fail truoc side effect. |
| [`../evidence/artifacts/pipeline-metadata.txt`](../evidence/artifacts/pipeline-metadata.txt) | Artifact metadata cua build. |
| [`../evidence/artifacts/security-integration-status.txt`](../evidence/artifacts/security-integration-status.txt) | Artifact tinh trang scanner integration. |
| [`../evidence/local-registry-tags.json`](../evidence/local-registry-tags.json) | Registry co immutable SHA tag. |
| [`../evidence/screenshots/task2-01-jenkins-stages.png`](../evidence/screenshots/task2-01-jenkins-stages.png) | Stage View co build `#1` thanh cong va hai negative build. |
| [`../evidence/screenshots/task2-01b-jenkins-build-push-stages.png`](../evidence/screenshots/task2-01b-jenkins-build-push-stages.png) | Stage 8 build va stage 11 push image cua hang build thanh cong. |
| [`../evidence/screenshots/task2-02-security-artifacts.png`](../evidence/screenshots/task2-02-security-artifacts.png) | Danh sach artifact tren Jenkins. |

## Cach danh gia

`DAT` khi:

1. Build ket thuc `SUCCESS`.
2. Log co `Source`, full commit SHA va immutable `IMAGE_URI`.
3. Registry co tag commit, khong chi co `latest`.
4. Jenkins artifact co it nhat `pipeline-metadata.txt` va
   `security-integration-status.txt`.
5. Negative build `SECURITY_MODE=enforce` fail voi thong bao
   `Secrets scan integration is not ready` khi script secrets con rong.

Ket luan hien tai: **DAT tren local registry voi SECURITY_MODE=stub**. Security
scan that chua duoc tinh la dat cho toi khi contract va vulnerability fail/pass
policy cua Thanh vien 3 hoan tat.
