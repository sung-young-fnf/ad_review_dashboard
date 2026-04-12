---
name: deploy-validate
description: "배포 후 자동 검증 — ArgoCD 동기화, 마이그레이션, 헬스체크, 이상 감지. Use when: 푸시 후 배포 상태 확인, 배포 문제 진단"
effort: medium
preconditions:
  - 코드가 push된 상태
allowed-tools:
  - Bash
  - Read
  - Grep
  - mcp__argocd-mcp__list_applications
  - mcp__argocd-mcp__get_application
  - mcp__argocd-mcp__get_application_resource_tree
  - mcp__argocd-mcp__get_application_events
  - mcp__argocd-mcp__get_resource_events
  - mcp__datadog__get_monitors
  - mcp__datadog__get_logs
  - mcp__datadog__list_hosts
  - mcp__datadog__query_metrics
  - mcp__serena__write_memory
user-invocable: true
context: fork
---

# Deploy Validate Skill

> 배포 후 자동 검증 파이프라인 — "푸시하고 기도하기" 종료

## Pre-injected Context (Dynamic Context Injection)

**현재 브랜치:**
!`git branch --show-current 2>/dev/null`

**미push 커밋:**
!`git log origin/$(git branch --show-current 2>/dev/null)..HEAD --oneline 2>/dev/null || echo "(리모트 비교 불가)"`

**최근 push된 커밋 (5개):**
!`git log --oneline -5 2>/dev/null`

**현재 시간 (epoch — Datadog 쿼리용):**
!`date -u +%s`

## WHY

Insights: "tools disappearing after K8s refresh, cache poisoning on failure, missing migrations"
배포 후 수동 확인 누락 → 프로덕션 이슈로 발전하는 패턴 반복.
이 스킬은 배포 후 6단계 자동 검증을 수행.

## 6-Step 검증 파이프라인

### Step 1: Git Push 확인

Pre-injected 미push 커밋 목록을 확인합니다.

**미push 커밋 존재 시:** 경고 + push 제안 (자동 push 안 함)

### Step 2: ArgoCD Sync 상태

```
argocd-mcp/get_application → sync status 확인
- Synced + Healthy → PASS
- OutOfSync → 자동 재시도 대기 (최대 3분)
- Degraded → 리소스 트리 분석 + 이벤트 확인
```

### Step 3: Pod 상태 확인

```bash
# kubectl로 pod 상태 확인
kubectl get pods -n {namespace} -l app={service} --sort-by=.metadata.creationTimestamp
```

- Running + Ready → PASS
- CrashLoopBackOff → 로그 수집 + 진단
- ImagePullBackOff → 이미지 태그 확인

### Step 4: 마이그레이션 확인

```bash
# ai-agent (Prisma)
npx prisma migrate status

# mcp-orbit (Alembic)
alembic current
alembic heads
```

**Applied 미매치 시:** 경고 + 마이그레이션 실행 제안

### Step 5: 헬스체크 + API 검증

```bash
# /health 엔드포인트 확인 (서비스별)
curl -s {service_url}/health | jq .status

# 핵심 API 비어있지 않은 응답 확인
curl -s {service_url}/api/{critical_endpoint} | jq 'length'
```

**빈 응답 시:** 캐시 포이즈닝 의심 → DB 직접 조회로 교차 검증

### Step 6: 메트릭 이상 감지

```
datadog/query_metrics → CPU/Memory 확인
- CPU > 80% (5분 지속) → HPA 스케일아웃 확인
- Memory > 90% → 메모리 누수 의심
- Error rate > 1% → 로그 분석
```

## 검증 리포트

```
## 배포 검증 리포트

| 항목 | 상태 | 비고 |
|------|------|------|
| Git Push | PASS | 3 commits pushed |
| ArgoCD Sync | PASS | Synced + Healthy |
| Pod Status | PASS | 3/3 Running |
| Migration | PASS | Up to date |
| Health Check | PASS | 200 OK |
| Metrics | PASS | CPU 45%, Memory 60% |

**결과: ALL PASS** — 배포 정상 완료
```

## 이상 감지 시 행동

| 심각도 | 조건 | 행동 |
|--------|------|------|
| INFO | OutOfSync (1분 이내) | 대기 + 재확인 |
| WARN | Pod 재시작 1회 | 로그 확인 + 보고 |
| ERROR | CrashLoop / Degraded | 즉시 보고 + 롤백 제안 |
| CRITICAL | 전체 서비스 다운 | 즉시 보고 + 이전 리비전 롤백 제안 |

**자동 롤백은 수행하지 않음** — 항상 사용자 승인 후 진행.

## 완료 기준

- 6단계 모두 검증 완료
- 검증 리포트 출력
- 이상 발견 시 진단 + 제안 포함
- serena 메모리에 배포 상태 기록
