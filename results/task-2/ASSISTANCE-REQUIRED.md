# Dau vao va anh chup con thieu

Khong the tao trung thuc cac bang chung duoi day tu may local hien tai. Can nguoi
dung hoac thanh vien phu trach cung cap quyen/moi truong; sau do chay cac lenh
xac minh trong ho so tuong ung.

## 1. CICD-02 - Amazon ECR

Can tu Thanh vien 1:

- `AWS_ACCOUNT_ID` hoac hostname `ECR_REGISTRY`.
- Region va ten ECR repository.
- IAM role/credential co quyen login, push va describe image.
- Xac nhan duoc phep tao mot image tag kiem thu tren ECR.

Anh can chup sau khi pipeline thanh cong:

`evidence/screenshots/task2-03-ecr-sha-tag.png`

Anh phai thay duoc repository, tag 12 ky tu commit SHA, digest va pushed time.
Khong de access key, secret key, session token hay password trong anh.

## 2. CICD-03 - Argo CD staging

May hien tai:

- Khong tim thay lenh `k3d`.
- `kubectl config current-context` khong co context.
- Khong co Argo CD runtime de truy van Application.

Can tu Thanh vien 1:

- K3d/EKS cluster dang hoat dong va kubeconfig.
- Argo CD da cai trong namespace `argocd`.
- Cluster co the pull image tu registry da chon.
- Quyen apply `cd/apps/staging.yaml` va doc Application status.

Anh can chup:

`evidence/screenshots/task2-05-argocd-staging-healthy.png`

Anh/output phai co ten `tetris-staging`, `Sync Status: Synced`, `Health Status:
Healthy` va revision dang theo doi.

## 3. CICD-04 - production runtime va approval

Can tu Thanh vien 3:

- Hoan thien `ci/stages/secrets-scan.sh`.
- Chot exit policy/report contract cho tat ca security scripts, dac biet
  vulnerability threshold cua Checkov/Trivy, de
  `SECURITY_MODE=enforce` chay qua khi khong co loi.

Can tu Thanh vien 1/4:

- Production cluster/ECS service va image-pull permission.
- Neu dung ECS: cluster, service, task family va container name that.

Anh can chup:

- `evidence/screenshots/task2-06-production-approval.png`
- `evidence/screenshots/task2-07-production-result.png`

Anh dau phai cho thay build dang cho `Production Approval`; anh sau phai cho
thay production `Healthy`/service stable va dung dung SHA image da duoc approve.

## 4. Cach gui thong tin an toan

Khong commit credential vao repository va khong dan secret vao screenshot.
Nhap secret truc tiep vao Jenkins Credentials, AWS profile/SSO hoac IAM role.
Chi can gui cho nguoi thuc hien cac gia tri khong bi mat nhu ECR hostname,
repository, region, cluster/service name va URL Argo CD.
