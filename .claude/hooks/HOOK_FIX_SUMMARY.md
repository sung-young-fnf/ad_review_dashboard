# Hook System 수정 완료 보고서

> **날짜**: 2025-11-19
> **문제**: user-prompt-submit Hook이 실행되지 않음
> **원인**: 디렉토리 구조 변경으로 인한 Hook 실행 실패

---

## 🔍 문제 원인

### **타임라인**
- **며칠 전**: Hook 정상 작동 ✅
- **어제 (Nov 18)**: 스크린샷 Hook 개발
- **오늘 (Nov 19)**: user-prompt-submit Hook 미작동 ❌

### **근본 원인**
```bash
# Before (정상):
.claude/hooks/pre/user-prompt-submit.sh  ← 단일 파일 (Claude Code가 실행)

# After (문제):
.claude/hooks/pre/user-prompt-submit/    ← 디렉토리로 변경
  └── 003-screenshot-context-injector.sh ← 서브 Hook만 있음
```

**Claude Code는 `user-prompt-submit.sh` 파일을 찾지만, 디렉토리로 바뀌어서 실행 불가**

---

## ✅ 해결 방법

### **Step 1: 기존 구조 백업**
```bash
mv user-prompt-submit user-prompt-submit.d
mv user-prompt-submit.sh user-prompt-submit-main.sh
```

### **Step 2: 통합 Hook 생성**
```bash
# user-prompt-submit.sh (NEW - 통합 버전)
#!/bin/bash
# Phase 1: Main Context Injection (기존 로직)
# Phase 2: Screenshot Context Injection (신규 로직)
```

**핵심 설계**:
1. **Phase 1**: 메인 Hook (`user-prompt-submit-main.sh`) 호출
   - AUTO-CONTEXT INJECTION
   - Agent 추천
   - 기술 컨텍스트 주입

2. **Phase 2**: 스크린샷 키워드 감지
   - 키워드: "스크린샷", "화면", "UI", "버튼", "깨짐" 등
   - Screenshot Analysis Protocol 자동 활성화
   - Chrome DevTools 메타데이터 수집 가이드

---

## 🧪 테스트 결과

### Test 1: 일반 요청
```bash
CLAUDE_USER_PROMPT="프로젝트 분석해줘" user-prompt-submit.sh
```

**출력**:
```
╔═══════════════════════════════════════════════════════════════════════════╗
║                    🎯 AUTO-CONTEXT INJECTION (Phase 1)                    ║
╚═══════════════════════════════════════════════════════════════════════════╝

ANALYZE:
  키워드: [story]
  도메인: [general]

INJECT:
  📋 Agent 추천: 02-requirements/story-creator
  🔧 기술 컨텍스트: React + Next.js + TypeScript + Prisma
  ...
```

✅ **정상 작동**

### Test 2: 스크린샷 요청
```bash
CLAUDE_USER_PROMPT="스크린샷을 보니 버튼이 안보여" user-prompt-submit.sh
```

**출력**:
```
╔═══════════════════════════════════════════════════════════════════════════╗
║                    🎯 AUTO-CONTEXT INJECTION (Phase 1)                    ║
╚═══════════════════════════════════════════════════════════════════════════╝
...

╔═══════════════════════════════════════════════════════════════════════════╗
║              📸 SCREENSHOT ANALYSIS PROTOCOL (자동 활성화)                 ║
╚═══════════════════════════════════════════════════════════════════════════╝

⚠️ **필수 3-Step**:
1. Metadata Collection (Chrome DevTools)
2. Context Merge (분석)
3. 정확한 위치 파악
...
```

✅ **두 기능 모두 작동**

---

## 📁 최종 구조

```
.claude/hooks/pre/
├── user-prompt-submit.sh          ← 통합 Hook (NEW)
├── user-prompt-submit-main.sh     ← 메인 로직 (기존)
├── user-prompt-submit.d/          ← 백업 디렉토리
│   └── 003-screenshot-context-injector.sh
└── ... (기타 Hooks)
```

---

## 🎯 핵심 개선 사항

### **Before (문제)**
- 디렉토리 구조로 변경 → Claude Code 실행 불가
- 메인 Hook과 스크린샷 Hook 분리
- Hook 간 통합 없음

### **After (해결)**
- 단일 파일로 복원 → Claude Code 정상 실행 ✅
- 메인 Hook + 스크린샷 Hook 통합 ✅
- 조건부 활성화 (키워드 감지) ✅

---

## 📝 배운 교훈

### **Hook 개발 원칙**
1. ✅ **단일 파일 유지**: Claude Code는 `<hook-name>.sh` 파일을 찾음
2. ✅ **디렉토리 금지**: `<hook-name>/` 디렉토리는 무시됨
3. ✅ **통합 설계**: 여러 기능은 하나의 Hook에서 조건부 처리
4. ✅ **Graceful Degradation**: 모든 에러는 `exit 0`

### **디버깅 팁**
1. Hook 수동 실행: `CLAUDE_USER_PROMPT="..." hook.sh`
2. 로그 확인: `echo "[hook] message" >&2`
3. 타임라인 추적: `git log --oneline --since="2 days ago"`
4. 구조 비교: `ls -lt .claude/hooks/pre/`

---

## ✅ 체크리스트

- [x] 문제 원인 파악 (디렉토리 구조 변경)
- [x] 기존 구조 백업 (user-prompt-submit.d/)
- [x] 통합 Hook 생성 (user-prompt-submit.sh)
- [x] 일반 요청 테스트 (Phase 1)
- [x] 스크린샷 요청 테스트 (Phase 2)
- [x] 문서 작성 (본 문서)

---

## 🚀 다음 단계

1. **Claude Code 재시작** (Hook 캐시 초기화)
2. **실제 사용 테스트** (사용자 입력 시 Hook 자동 실행 확인)
3. **로그 모니터링** (필요 시 `/tmp/claude-hook-user-prompt-submit.log`)

---

## 📚 참조

- **Hook 코드**: `.claude/hooks/pre/user-prompt-submit.sh`
- **메인 로직**: `.claude/hooks/pre/user-prompt-submit-main.sh`
- **백업 디렉토리**: `.claude/hooks/pre/user-prompt-submit.d/`
- **Troubleshooting**: `.claude/hooks/HOOK_TROUBLESHOOTING.md`
- **개발 가이드**: `.claude/guides/HOOK_DEVELOPMENT_GUIDE.md`
