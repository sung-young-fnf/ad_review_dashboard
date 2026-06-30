# {SERVICE} 운영 가이드 (template)

> 신규 서비스 만들 때 `{service-repo}/docs/OPS.md` 로 복사 후 치환. 배포/롤백/장애 대응 표준.

## 환경

| env | Cluster | Namespace | Domain |
|-----|---------|-----------|--------|
| dev | dt-ane2-eks-dev-general | {service}-dev | https://{service}-dev.fnf.co.kr |
| prd | dt-ane2-eks-prd-general | {service}-prd | https://{service}.fnf.co.kr |

## 배포 흐름

### dev — 자동
```
{branch} push → GitHub Actions ({service}-backend-dev.yml / -frontend-dev.yml)
   → Docker build → ECR push (dt-ane2-ecr-{service}-{component})
   → values-dev.yaml image.tag 자동 갱신 commit
   → ArgoCD 자동 sync (3분 reconcile 또는 hard refresh)
   → Pod rolling update
```

### prd — tag 기반 promote
```
git tag vX.Y.Z && git push --tags
   → deploy-prd.yml trigger
   → tag 시점의 values-dev.yaml 의 image.tag 를 values-prd.yaml 로 복사 commit
   → ArgoCD prd Application 자동 sync
```

워크플로 dispatch 로 임의 tag promote 가능 (롤백/긴급).

## 롤백

| 시나리오 | 방법 |
|---------|------|
| prd 새 release 문제 | Actions → `deploy-prd` workflow_dispatch → 이전 tag 입력 → 자동 promote |
| dev 문제 | revert PR 또는 직전 image.tag 로 values-dev 수정 |
| ArgoCD sync 안됨 | `kubectl --context {cluster} -n argocd annotate application {service}-{env} argocd.argoproj.io/refresh=hard --overwrite` |

## 장애 대응 (흔한 케이스)

### Pod CrashLoopBackOff
```bash
kubectl --context dt-ane2-eks-{env}-general -n {service}-{env} describe pod <pod>
kubectl --context dt-ane2-eks-{env}-general -n {service}-{env} logs <pod> --previous
```
- `CreateContainerConfigError` → ExternalSecret sync 확인 (`kubectl get externalsecret`)
- `ImagePullBackOff` → values 의 image.tag 가 ECR 에 실존하는지

### DB 연결 실패
- Aurora cluster endpoint 변경 여부 (`aws rds describe-db-clusters`)
- Pod Identity SG / cluster SG ingress 5432 허용
- ExternalSecret 의 DATABASE_URL key 갱신

### ALB 5xx / target unhealthy
- Pod Ready 상태 확인 + readinessProbe path/port
- ALB target group 의 health check 응답

## 모니터링

| 도구 | URL/Path |
|------|---------|
| Datadog APM | `service:{service}-api`, `env:{env}` |
| CloudWatch Logs | EKS Container Insights |
| ArgoCD | https://prcs-argocd.fnf.co.kr/applications/{service}-{env} |

## 권한 / 접근

- ArgoCD UI: MS Entra SSO 로그인 → AD 그룹 `prcs-argocd-{service}-admin` 멤버여야 본인 Application 보임
- AWS 콘솔: SSO `prcs-app-dev`/`admin` 등급 (Phase 2 권한 매트릭스)
- DB 직접 접속: DBGate (https://dbgate.fnf.co.kr) — readonly 그룹 멤버 필요

## 참고

- `docs/API-USAGE.md` — API 사용법
- root `CLAUDE.md` — AI 참조 entry
- prcs-terraform `.claude/rules/permission-routing.md` — 본인 처리 vs 인프라 요청
