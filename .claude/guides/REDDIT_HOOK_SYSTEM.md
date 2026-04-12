# 🚀 REDDIT HOOK SYSTEM INTEGRATION

> **혁신**: Reddit Claude Code 커뮤니티의 Hook 패턴을 Agent 워크플로우에 통합

## 🔄 Enhanced 4-Step Workflow (NEW)

### 기존 3단계에서 4단계로 확장
```yaml
# 기존: STOP → CHECK → ROUTE
# 개선: STOP → ANALYZE → INJECT → ROUTE

STOP: 즉시 코드를 보지 말 것 (기존 유지)
ANALYZE: 키워드 + 인텐트 + 컨텍스트 분석 (🆕 신규)
INJECT: 동적 컨텍스트 주입 (🆕 신규)
ROUTE: Agent 체인 실행 (기존 유지)
```

### ANALYZE 단계 (Context Injector Agent)
```yaml
기능:
  - 키워드 + 인텐트 패턴 분석
  - 프로젝트별 컨텍스트 매칭 (okr2, React, TypeScript)
  - Agent 스킬 매칭 (epic-creator의 MVP 전문성)
  - 사용자 패턴 학습 (pattern-learner 연동)

출력:
  analysis: { complexity: "story", domain: "auth", tech_stack: ["react"] }
```

### INJECT 단계 (Dynamic Context Injection)
```yaml
컨텍스트 주입 템플릿:
  🎯 {DOMAIN} {INTENT} DETECTED
  📋 Agent 추천: {best_agent} ({expertise} 전문)
  🔧 기술 컨텍스트: {project_patterns}
  ⚠️ 주의사항: {risk_warnings}
  💡 품질 체크포인트: {quality_gates}

예시:
  "🎯 AUTH SYSTEM DETECTED
   📋 Agent 추천: epic-creator (인증 시스템 MVP 전문)
   🔧 기술 컨텍스트: NextAuth.js + JWT + sparknote 스키마
   ⚠️ 주의사항: session.backendToken 사용, DB ENUM 금지
   💡 품질 체크포인트: OWASP 가이드라인, React Hook deps"
```

## 🛡️ Post-Execution Quality Gate (NEW)

### Reddit Stop Event Hook 패턴 적용
```yaml
트리거:
  - code-writer Agent 완료 시 자동 실행
  - 파일 편집 감지 시 (*.tsx, *.ts, *.js)
  - error-fixer Agent 완료 시

체크 항목:
  React: useEffect deps, Hook rules, memory leaks
  API: error handling, authentication, HTTP methods
  DB: schema prefix (sparknote.), ENUM 금지, transactions
  TypeScript: strict types, unused imports, naming

출력 (Non-blocking):
  "✅ Quality Gate Complete (2.3s)
   📝 Code Quality Report: [상세 검증 결과]
   💡 Gentle Suggestions: [부드러운 개선 제안]
   🎯 Overall Score: 94/100 (Excellent)"
```

## 🧠 Pattern Learning System (NEW)

### 사용자 개발 패턴 학습
```yaml
학습 데이터:
  - Agent 사용 선호도 (story-chain 60%, epic-chain 15%)
  - 기술 스택 패턴 ([react, typescript, nextjs])
  - 품질 이슈 빈도 (useEffect-deps 15%, api-errors 10%)
  - 성공 워크플로우 (story → task → code 95% 성공률)

개인화 컨텍스트:
  "🧠 PERSONALIZED CONTEXT
   📊 Based on your patterns: Story Chain (95% success rate)
   🔧 Your Tech Stack: React + TypeScript + NextAuth.js
   ⚠️ Personal Risk Areas: useEffect infinite loops (15% frequency)
   💡 Success Pattern: API-first → UI implementation"
```

## 📋 통합 실행 예시

### 사용자 입력: "댓글 시스템 추가해줘"

```
**[Enhanced 4-Step Workflow]**

ANALYZE:
  키워드: ["댓글", "시스템", "추가"]
  인텐트: create + story 복잡도
  도메인: API + UI 결합

INJECT:
  🎯 CRUD + UI SYSTEM DETECTED
  📋 Agent 추천: story-creator (CRUD + UI 통합 전문)
  🔧 기술 컨텍스트: React + Next.js API + sparknote.comments
  ⚠️ 주의사항: 중첩 API 라우트, React Hook deps, DB 스키마 prefix
  💡 예상 Story: S01 DB+API → S02 UI → S03 폼 → S04 실시간

ROUTE:
  - 요청 분류: 중형 (API + UI 결합)
  - 자동 실행: story-creator --crud-ui-context --hard-think --delegate

POST-EXECUTION (자동):
  ✅ Quality Gate: React Hook deps 검증, API 에러 핸들링 체크
  📝 Pattern Learning: CRUD 성공 패턴 +1, 완료 시간 기록
```

---

**참조**: `.claude/CLAUDE.md` → AUTO-WORKFLOW 자동 라우팅, MANDATORY WORKFLOW EXECUTION RULES
