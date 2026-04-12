# MCP Orchestrator Constitution v1.0.0

> **프로젝트 헌법**: 모든 Epic/Story/Task가 준수해야 할 5가지 핵심 원칙
> **적용 시점**: Phase 0 (계획) 게이트 + Phase 1 (설계) 재확인

---

## 🏛️ 5대 원칙 (Five Principles)

### I. 코드 품질 원칙 (Code Quality)

**필수 기준**:
- 가독성 우선 (self-documenting code)
- 명확한 네이밍 (kebab-case 파일, camelCase 변수)
- 매직넘버 금지 (상수로 추출)
- 복잡도 정당화 (복잡한 로직은 주석 필수)

**근거**: 유지보수 비용 절감, 새 팀원 온보딩 시간 단축

```yaml
검증 방법:
  - ESLint/Pylint 통과
  - 함수 50줄 이하
  - 파일 200줄 이하
```

---

### II. 테스트 주도 원칙 (Test-Driven)

**필수 기준**:
- 핵심 로직 테스트 커버리지 80%+
- API 엔드포인트 통합 테스트 필수
- 실패 우선 접근 (Red → Green → Refactor)

**근거**: 회귀 버그 방지, 리팩토링 안전망

```yaml
검증 방법:
  - pytest --cov (Backend)
  - vitest run --coverage (Frontend)
  - 신규 API = 테스트 필수
```

**예외 허용**:
- UI 컴포넌트 (시각적 테스트 대체)
- 프로토타입/PoC (명시적 태그 필요)

---

### III. UX 일관성 원칙 (UX Consistency)

**필수 기준**:
- 통일된 디자인 패턴 (shadcn/ui 기반)
- 명확한 에러 메시지 (무엇/왜/어떻게)
- 로딩/성공/에러 상태 표시
- 키보드 내비게이션 지원

**근거**: 사용자 경험 품질, 브랜드 일관성

```yaml
검증 방법:
  - 에러 메시지 3요소 포함 (what, why, how)
  - 로딩 스피너/스켈레톤 존재
  - Tab 키로 모든 인터랙션 접근 가능
```

---

### IV. 성능 기준 원칙 (Performance Standards)

**필수 기준**:
- API p95 응답시간 < 500ms
- N+1 쿼리 회피 (ORM 최적화)
- 프론트엔드 초기 로드 < 3초
- 메모리 누수 방지

**근거**: 사용자 이탈 방지, 인프라 비용 절감

```yaml
검증 방법:
  - SQLAlchemy eager loading 사용
  - React.memo / useMemo 적절히 사용
  - Lighthouse 성능 점수 70+
```

---

### V. 유지보수성 원칙 (Maintainability)

**필수 기준**:
- 모듈화 (단일 책임 원칙)
- 느슨한 결합 (인터페이스 기반)
- 의미론적 버저닝 (MAJOR.MINOR.PATCH)
- 변경 영향 범위 최소화

**근거**: 장기적 개발 속도 유지, 기술 부채 관리

```yaml
검증 방법:
  - 순환 의존성 없음
  - 한 파일 변경 시 영향 파일 5개 이하
  - Breaking change 시 MAJOR 버전 증가
```

---

## ✅ Constitution Check 템플릿

### Phase 0 (계획 단계) 게이트

```markdown
## Constitution Check - Phase 0

### I. 코드 품질
- [ ] 네이밍 규칙 정의됨
- [ ] 복잡도 기준 설정됨

### II. 테스트 주도
- [ ] 테스트 전략 정의됨
- [ ] 커버리지 목표 설정됨 (80%+)

### III. UX 일관성
- [ ] 에러 메시지 형식 정의됨
- [ ] 상태 표시 방식 정의됨

### IV. 성능 기준
- [ ] 응답시간 목표 설정됨
- [ ] 쿼리 최적화 계획됨

### V. 유지보수성
- [ ] 모듈 구조 정의됨
- [ ] 의존성 관리 계획됨

**GATE**: 모든 체크박스 완료 → Phase 1 진입 허용
```

### Phase 1 (설계 단계) 재확인

```markdown
## Constitution Check - Phase 1 (재확인)

- [ ] 설계가 5대 원칙을 모두 준수함
- [ ] 위반 사항 없음 또는 정당화 완료

**위반 정당화 (있는 경우)**:
| 원칙 | 위반 내용 | 정당화 |
|------|----------|--------|
| - | - | - |
```

---

## 🚫 위반 시 처리

```yaml
위반 감지 시:
  1. 작업 중단 (STOP)
  2. 위반 원칙 식별
  3. 정당화 가능 여부 판단
     - 정당화 가능 → 위반 정당화 테이블에 기록 후 진행
     - 정당화 불가 → 설계 수정 필요

자동 감지 (Hook 연동):
  - pattern-compliance-checker.sh → 원칙 IV, V 자동 검증
  - pre-edit-impact-analyzer.sh → 원칙 V 영향도 분석
```

---

## 📋 개정 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 1.0.0 | 2024-12-10 | 초기 버전 (cc-wf-studio 패턴 적용) |

---

## 📚 참조

- **원본**: cc-wf-studio `.specify/memory/constitution.md`
- **연관 가이드**:
  - @.claude/guides/AGENT_CHAIN_RULES.md
  - @.claude/guides/AUTO_WORKFLOW_GUIDE.md
  - @.claude/guides/TASK_SIZING_GUIDE.md

---

_YAGNI + Constitution = 즉시 가치 + 품질 보장_
