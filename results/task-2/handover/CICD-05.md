# CICD-05 - Jenkins credentials

## Yeu cau ban giao

- Co bang credential can dung va ghi ro credential ID.
- Pipeline khong hardcode token/secret.
- Pipeline chay ma khong lam lo secret trong code/log.

## Bang credentials

| Credential ID | Jenkins type | Noi dung | Khi dung | Nguoi cung cap |
|---|---|---|---|---|
| `github-token` | Username with password | Username `x-access-token`; password la fine-grained PAT co Contents read/write | Push GitOps commit | Repo owner |
| `aws-credentials` | Username with password | Username = access key ID; password = secret access key | Local Jenkins khi khong dung IAM role/SSO | Thanh vien 1 |
| `sonar-token` | Secret text | SonarQube token | `ENABLE_SAST=true` | Thanh vien 3 |
| `defectdojo-api-key` | Secret text | DefectDojo API key | Security integration tuy chon | Thanh vien 3 |
| `gitea-creds` | Username with password | Legacy local Gitea credential | Chi job cu neu con dung | Repo owner |

Khuyen nghi AWS: dung `AWS_AUTH_MODE=default-chain` voi IAM role tren AWS; chi
dung `aws-credentials` cho Jenkins local. Session token tam thoi duoc cap qua
environment/credential provider, khong dua vao Git.

## Cach cap secret

Local Compose:

1. Tao `.env` tu `ci/jenkins.env.example`.
2. Dien gia tri that trong `.env`.
3. Khong `git add .env`.
4. Restart Jenkins/JCasC de credentials duoc nap.

Jenkins UI:

`Manage Jenkins -> Credentials -> System -> Global credentials`

ID phai khop bang tren. Khong dat token vao Jenkins parameter string.

## Co che chong lo secret trong pipeline

- `withCredentials` mask credential trong console.
- ECR login va Git push dung `set +x`.
- Git token khong duoc chen vao remote URL hay `.git/config`.
- Cac file example chi chua placeholder/rong.
- Static scan tim AWS access key, GitHub token va private key pattern.

Bang chung:
[`../evidence/credential-secret-scan.txt`](../evidence/credential-secret-scan.txt).

Ket luan hien tai: **DAT VE THIET KE/CODE**. Khi dua credential that vao Jenkins,
can kiem tra lai console log va screenshot de dam bao khong co gia tri bi lo.
