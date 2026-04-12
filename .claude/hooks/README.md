# Claude Code Hook System for okr2

> **혁신적 통합**: Reddit Claude Code 커뮤니티의 Hook 패턴을 Claude Code 공식 문법으로 구현한 하이브리드 시스템

## 🎯 시스템 개요

기존 69개 Agent 워크플로우에 Reddit Hook 패턴(UserPromptSubmit + Stop Event)을 Claude Code 공식 문법으로 통합한 엔터프라이즈급 품질 보증 시스템입니다.

### 핵심 특징

- **Enhanced 4-Step Workflow**: 기존 3단계를 4단계로 확장 (STOP → ANALYZE → INJECT → ROUTE)
- **Dynamic Context Injection**: 프로젝트별(okr2) 컨텍스트 자동 주입
- **Real-time Quality Gate**: 코드 편집 완료 후 자동 품질 검증
- **Pattern Learning**: 사용자 개발 패턴 학습 및 개인화

## 🔧 설치 및 설정

### 1. 자동 설정 (이미 완료됨)

Hook 시스템은 다음과 같이 구성되어 있습니다:

```
.claude/
├── settings.json           # Claude Code Hook 이벤트 등록
└── hooks/
    ├── package.json        # Node.js 의존성
    ├── tsconfig.json       # TypeScript 설정
    ├── user-prompt-submit.sh + .ts     # Pre-execution Hook
    ├── post-tool-use-tracker.sh        # Tool tracking
    ├── stop-quality-gate.sh + .ts      # Quality analysis
    └── stop-pattern-learning.sh + .ts  # Learning system
```

### 2. 의존성 확인

```bash
cd .claude/hooks
npm install  # 이미 설치됨
```

### 3. 권한 확인

```bash
chmod +x .claude/hooks/*.sh  # 이미 설정됨
```

## 🚀 Hook 시스템 작동 방식

### UserPromptSubmit Hook (Pre-Execution)

**실행 시점**: 사용자 메시지 입력 직후, Claude가 보기 전
**파일**: `user-prompt-submit.sh` + `user-prompt-submit.ts`

#### Enhanced 4-Step Analysis Engine

1. **ANALYZE**: 키워드 + 인텐트 + 컨텍스트 분석
2. **PROJECT MATCHING**: okr2 프로젝트 패턴 매칭
3. **AGENT SELECTION**: 최적 Agent 추천
4. **CONTEXT INJECTION**: 동적 컨텍스트 주입

#### 컨텍스트 주입 예시

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧠 CLAUDE CONTEXT INJECTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 AUTH SYSTEM DETECTED

📋 Recommended Agent: epic-creator
   Expertise: MVP design, user stories, auth systems
   Confidence: 95% (Authentication system requires comprehensive MVP design)

🔧 okr2 Technical Context:
   - NextAuth.js + JWT + Bearer Token
   - PostgreSQL sparknote schema (NO PostgreSQL ENUM types)
   - session.backendToken authentication (NOT accessToken)
   - X-Impersonate-User header for admin features

⚠️ Critical Warnings:
   - NO PostgreSQL ENUM types: Use VARCHAR + TypeScript literal types
   - OWASP Authentication Guidelines compliance required
   - Admin impersonation pattern mandatory for all auth endpoints

💡 Quality Checkpoints:
   - React Hook dependency array validation
   - API error handling completeness
   - Database schema prefix compliance (sparknote.)
   - Authentication flow security validation

📋 Predicted Workflow: Epic → Story → Task → Implementation
🕒 Estimated Timeline: 25-30 minutes (based on similar Epic tasks)

🎯 AUTO-WORKFLOW ROUTING:
   Enhanced 4-Step: STOP → ANALYZE → INJECT → ROUTE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### PostToolUse Hook

**실행 시점**: Edit, MultiEdit, Write 도구 사용 후
**파일**: `post-tool-use-tracker.sh`

파일 편집을 추적하고 Quality Gate 분석을 위한 메타데이터를 수집합니다.

### Stop Hooks (Post-Execution)

**실행 시점**: Claude 응답 완료 후 자동 실행

#### 1. Quality Gate Hook

**파일**: `stop-quality-gate.sh` + `stop-quality-gate.ts`

##### 품질 검증 영역

- **React Components**: useEffect deps, Hook rules, memory leaks
- **API Routes**: error handling, authentication, HTTP methods
- **Database Operations**: schema prefix, ENUM 금지, transactions
- **TypeScript**: strict types, unused imports, naming

##### 출력 예시

```
✅ Quality Gate Complete (1.2s)

📝 Code Quality Report:
  📱 React Components: ✅ 2 files checked
    - useEffect dependencies: ✅ All primitive values
    - Hook usage: ✅ No conditional hooks
    - Memory management: ✅ No leaks detected

  🔌 API Routes: ⚠️ 1 warning
    - Error handling: ✅ Try-catch blocks present
    - Authentication: ✅ Bearer token validation
    - HTTP methods: ⚠️ Consider adding DELETE method

  🗄️ Database Operations: ✅ All checks passed
    - Schema prefix: ✅ sparknote. prefix used consistently
    - Query safety: ✅ Parameterized queries
    - No ENUM usage: ✅ VARCHAR + TypeScript literals

💡 Gentle Suggestions:
  - Consider adding DELETE method to API route
  - Optional: Add integration tests for new components

🎯 Overall Score: 94/100 (Excellent)
```

#### 2. Pattern Learning Hook

**파일**: `stop-pattern-learning.sh` + `stop-pattern-learning.ts`

사용자 개발 패턴을 학습하고 개인화된 인사이트를 제공합니다.

##### 학습 데이터

- **Workflow Preferences**: epic-chain vs story-chain vs task-chain
- **Domain Expertise**: auth, ui, api, db, deployment 숙련도
- **Quality Evolution**: react_hooks, api_errors, db_patterns 개선도
- **Success Patterns**: 성공적인 개발 패턴 식별

##### 출력 예시

```
📚 Pattern Learning Update:
  ✅ STORY completion: +1 success
  ⏱️ Completion time: 18.5 minutes (faster than average)
  🎯 Quality score: 94/100 (above your 89 average)
  📈 API expertise: 87% (proficient)

🧠 Learning Insights:
  • Your React Hook dependency management: mastered ✅
  • API development skills: strong expertise gained
  • Database schema patterns: consistent application ✅
  💡 Suggested focus area: deployment development (45% confidence)
```

## 📋 okr2 프로젝트 특화 패턴

### Authentication System
- **Tech Stack**: NextAuth.js + JWT + Bearer Token
- **Database**: PostgreSQL sparknote schema
- **Warning**: NO ENUM types, session.backendToken 사용

### API Development
- **Pattern**: Next.js App Router + Proxy Pattern
- **Auth**: session.backendToken + X-Impersonate-User header
- **Environment**: API_BASE_URL || BACKEND_URL || NEXT_PUBLIC_BACKEND_URL

### UI Components
- **Framework**: React 18 + TypeScript + Tailwind
- **Hooks**: Primitive dependencies only, useMemo stabilization
- **Warning**: useEffect infinite loops 방지

### Database Operations
- **Schema**: sparknote (MANDATORY prefix)
- **Prohibition**: PostgreSQL ENUM types
- **Alternative**: VARCHAR + TypeScript literal types

## 🔍 디버깅 및 문제 해결

### Hook 실행 확인

Hook이 실행되지 않는 경우:

1. **권한 확인**: `ls -la .claude/hooks/*.sh`
2. **의존성 확인**: `cd .claude/hooks && npm list`
3. **설정 확인**: `.claude/settings.json` 내용 검증

### 로그 확인

Hook 실행 로그는 Claude Code의 시스템 로그에서 확인할 수 있습니다.

### 캐시 관리

```bash
# 세션 캐시 정리
rm -rf .claude/hooks-cache/*

# 사용자 학습 프로필 리셋
rm -f .claude/user-learning-profile.json
```

## 🚀 성과 지표

### 기대 효과

- **코드 품질**: React Hook 무한루프 95% 감소
- **개발 속도**: Agent 선택 시간 70% 단축
- **사용자 경험**: Agent 추천 정확도 75% → 95%
- **시스템 신뢰도**: 85% → 95%

### 학습 정확도

- **컨텍스트 관련성**: 목표 90%
- **패턴 인식**: 목표 95%
- **개인화 품질**: 목표 4.5/5

## 🔗 관련 문서

- [CLAUDE.md](../CLAUDE.md) - 프로젝트 메인 설정
- [AGENT_CATALOG.md](../AGENT_CATALOG.md) - 69개 Agent 목록
- [debugging-workflow.md](../../docs/analysis/debugging-workflow.md) - 디버깅 가이드

## 📄 라이선스

이 Hook 시스템은 okr2 프로젝트의 일부로 개발되었으며, Reddit Claude Code 커뮤니티의 오픈소스 패턴을 Claude Code 공식 문법으로 구현한 것입니다.

---

**구현 완료**: 2025-10-31
**상태**: Production Ready ✅
**다음 업그레이드**: 사용자 피드백 기반 개선