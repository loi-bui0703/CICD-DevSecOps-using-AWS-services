# Evidence index

| File | Nguon | Muc dich |
|---|---|---|
| `static-validation.txt` | `scripts/verify-handover.sh` | Tong hop test tinh. |
| `kustomize-staging-rendered.yaml` | `kubectl kustomize` | Xac minh overlay staging. |
| `kustomize-production-rendered.yaml` | `kubectl kustomize` | Xac minh overlay production. |
| `jenkinsfile-linter.txt` | Jenkins Declarative linter | Xac minh Jenkinsfile parse hop le. |
| `jenkins-build-success.log` | Jenkins build local | CICD-01 end-to-end local. |
| `jenkins-security-enforce-failure.log` | Jenkins negative build | Security fail-closed. |
| `jenkins-ecr-parameter-failure.log` | Jenkins negative build | Parameter fail truoc side effect. |
| `local-registry-tags.json` | Registry v2 API | Immutable tag da push. |
| `credential-secret-scan.txt` | Pattern scan | Khong thay mau secret pho bien. |
| `artifacts/*` | Jenkins archived artifacts | Metadata/security contract. |
| `screenshots/task2-01-jenkins-stages.png` | Jenkins Full Stage View | Build ID va ket qua ba kich ban. |
| `screenshots/task2-01b-jenkins-build-push-stages.png` | Jenkins Full Stage View da cuon ngang | Stage build/push image cua build thanh cong. |
| `screenshots/task2-02-security-artifacts.png` | Jenkins build #1 | SUCCESS, SHA va archived artifacts. |

Moi file phai chua output that hoac ghi ro `BLOCKED`; khong dung output mau de
thay bang chung runtime.
