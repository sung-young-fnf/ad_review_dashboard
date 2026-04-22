# ArgoCD Application CR (Hybrid GitOps 패턴)

이 디렉토리는 서비스 배포를 정의하는 ArgoCD `Application` 리소스를 보관합니다. `prcs-terraform` 의 `k8s/argocd/applications/services/{svc}-root.yaml` (App-of-Apps) 이 이 디렉토리를 감시하여 자동으로 sync 합니다.

## 역할 분리

| 영역 | 위치 | 주인 |
|------|------|------|
| ArgoCD Project (보안 경계) | `prcs-terraform/k8s/argocd/projects/{svc}.yaml` | 인프라팀 |
| root Application (App-of-Apps) | `prcs-terraform/k8s/argocd/applications/services/{svc}-root.yaml` | 인프라팀 (한 번 등록) |
| **서비스 Application CR** (dev/prd) | **이 디렉토리 (`argocd/`)** | **서비스팀** |
| Helm chart + values | `charts/{svc}/` | 서비스팀 |

## 파일

- `{{APP_NAME}}-dev.yaml` — develop 브랜치, `values-dev.yaml`, prune=true
- `{{APP_NAME}}-prd.yaml` — main 브랜치, `values-prd.yaml`, prune=false (수동 승인)

`create-app.sh`가 앱 생성 시 `{app_name}-*.yaml` 템플릿을 복사하며 `{{APP_NAME}}`, `{{REPO_NAME}}` placeholder를 실제 값으로 치환합니다.

## 체크리스트 (신규 앱 생성 후)

- [ ] `spec.project` 가 인프라팀이 정의한 Project 이름과 일치하는지 확인 (`prcs-terraform/k8s/argocd/projects/{svc}.yaml`)
- [ ] `destination.namespace` 가 `{svc}-{env}` 패턴인지 (ex. `fms-dev`, `fms-prd`)
- [ ] `source.repoURL` 이 실제 서비스 레포 HTTPS URL인지
- [ ] 프로덕션은 반드시 `automated.prune: false` (실수로 지워짐 방지)

## 금지

- ❌ `spec.project: default` 사용 (서비스 Project 바인딩 필수)
- ❌ `destination.namespace: '*'` 또는 다른 서비스 namespace 참조
- ❌ `prcs-terraform/k8s/argocd/applications/` 직접 커밋 (반드시 서비스 레포에서)
