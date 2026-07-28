# CICD-02 - Amazon ECR

## Yeu cau ban giao

- Jenkins login Amazon ECR.
- Build va push image theo commit SHA.
- ECR co image tag moi sau build.
- Co anh chup ECR repository.
- Khong chi su dung tag `latest`.

## Phan code da san sang

- `REGISTRY_TARGET=ecr` chon duong ECR.
- `ECR_REGISTRY` va `AWS_REGION` la parameter.
- `withAwsAuth` ho tro IAM/default credential chain hoac Jenkins credential.
- Stage 10 chay `aws ecr get-login-password` voi `set +x`.
- Stage 11 push `${IMAGE_URI}`; `latest` chi push tren release branch.
- Parameter validation chan hostname rong, co scheme hoac trailing slash.

## Trang thai va bang chung hien co

- **DAT** logic pipeline va negative parameter test.
- **CHUA DAT** push ECR that va screenshot do chua co ECR URI/IAM.
- Local registry da chung minh immutable tag flow, nhung khong thay the bang
  chung Amazon ECR.

Negative evidence:
[`../evidence/jenkins-ecr-parameter-failure.log`](../evidence/jenkins-ecr-parameter-failure.log).

## Lenh xac minh khi co AWS

```bash
aws ecr describe-images \
  --region ap-southeast-1 \
  --repository-name '<repository>' \
  --query 'sort_by(imageDetails,& imagePushedAt)[-5:].{tags:imageTags,digest:imageDigest,pushed:imagePushedAt}' \
  --output table
```

Chay Jenkins voi:

```text
REGISTRY_TARGET=ecr
ECR_REGISTRY=<account-id>.dkr.ecr.ap-southeast-1.amazonaws.com
IMAGE_REPOSITORY=<repository>
AWS_REGION=ap-southeast-1
SECURITY_MODE=stub
```

Sau khi thanh cong, luu output CLI vao
`../evidence/ecr-describe-images.txt` va anh UI vao
`../evidence/screenshots/task2-03-ecr-sha-tag.png`.

Ket luan hien tai: **CHO DAU VAO TU THANH VIEN 1**.
