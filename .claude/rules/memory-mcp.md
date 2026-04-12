---
globs: ["**"]
---

## Memory MCP 역할 (MANDATORY)
> 과거의 해결책과 결정을 재활용하고, 세션 간 지식이 유실되지 않는다

### Memory 삼원 체계 (v2.1.34+ Compound Engineering 도입)
| 메모리 유형 | 역할 | 관리 |
|------------|------|------|
| **`docs/solutions/`** (신규) | 풍부한 솔루션 문서 (문맥+코드+예방) | `/compound` 스킬 |
| **`docs/review-findings/`** (신규) | 리뷰 발견사항 Git 추적 | implementation-validator |
| **Agent `memory: project`** | 반복 패턴 자동 학습 (세션 간) | frontmatter 설정 (13개 agent 적용) |
| **serena/write_memory** | 중요 결정 영구 기록 | 수동 저장 |
| **historian** | 과거 대화/에러 검색 | 자동 인덱싱 |
| **praetorian** | 세션 압축 (90% 절감) | Task 완료 후 호출 |

[mcp-role: mcp, purpose, when]
serena, 코드분석+영구메모리, 심볼검색/중요결정저장
**historian**, 과거대화검색, **에러 발생 시 먼저 호출**
**praetorian**, 세션압축(90%절감), **Task 완료 후 반드시 호출**
**orbit-memory**, 사용자 장기 기억(AI Agent 동기화), **선호도/패턴/결정 저장·검색 시**
shadcn, UI컴포넌트 레지스트리, 컴포넌트검색/설치
**codex/gemini delegate**, 복잡한 문제 심층분석, 수정 2회+ 실패 시 (Task subagent로 위임)

### orbit-memory MCP 사용 가이드 (EP215)
> AI Agent 웹앱과 메모리를 양방향 동기화 — 여기서 저장하면 AI Agent 채팅에서도 참조 가능

**도구 목록:**
| Tool | 설명 | 언제 사용 |
|------|------|----------|
| `memory_save` | topic 기반 upsert | 사용자 선호도/패턴/결정 발견 시 저장 |
| `memory_search` | 키워드 검색 | "이전에 ~가 어떻다고 했지?" 질문 시 |
| `memory_list` | 전체 카탈로그 | 사용자 컨텍스트 파악 필요 시 |
| `memory_read` | topic 상세 조회 | 특정 선호도 상세 확인 |
| `memory_delete` | soft delete | 사용자가 삭제 요청 시 |
| `knowledge_search` | CoWork 지식 검색 | 업무 도메인 지식 필요 시 |
| `session_memory_search` | 과거 채팅 LTM | "지난번 채팅에서 뭘 결론냈지?" |

**자동 트리거 (권장):**
- 세션 시작 시 `memory_list` → 사용자 프로필/선호도 로드 (있으면)
- 사용자가 "기억해", "Remember" 등 요청 시 → `memory_save`
- 과거 대화/결정 질문 시 → `memory_search` 또는 `session_memory_search`
- "내 코딩 스타일은?", "우리 컨벤션이 뭐였지?" → `memory_search`

**topic 네이밍 규칙:**
```
preference/coding-style     # 코딩 선호도
preference/communication    # 소통 스타일
project/api-convention      # 프로젝트 규칙
decision/architecture       # 아키텍처 결정
context/team-structure      # 팀/조직 정보
skill/languages             # 기술 역량, 사용 언어/프레임워크
```

**업무 추적 활용:**
- 중요 결정/방향 전환 시 `memory_save` → topic: `decision/*`
- 반복 작업 패턴 발견 시 `memory_save` → topic: `project/*`
- `knowledge_search` — CoWork 세션에서 축적된 업무 도메인 지식 검색
- `session_memory_search` — 과거 AI 채팅에서 논의된 결론/결정 검색

**주의:**
- orbit-memory-mcp는 **전역 사용자 설정** (`~/.claude.json`) — 모든 프로젝트에서 사용 가능
- orbit-memory ≠ serena memory (역할 다름)
  - **orbit-memory**: 사용자 개인 기억 (AI Agent 웹앱과 양방향 동기화)
  - **serena**: 코드베이스 도메인 지식 (프로젝트 스코프)
- 코드베이스 관련 → serena, 사용자 개인 관련 → orbit-memory

### 🔴 필수 트리거
| 상황 | MCP 호출 | WHY |
|------|----------|-----|
| **🔥 에러 발생** | `historian/get_error_solutions` → `Grep docs/solutions/` | 같은 에러 반복 방지 (historian + 솔루션 문서 이중 검색) |
| 유사 작업 시작 | `learnings-researcher` → `historian/find_similar_queries` | **Local-First**: learnings-researcher가 docs/solutions/ 검색, 없으면 historian |
| **🔥 프론트엔드 API 추가** | `serena/read_memory` → frontend-api-proxy-checklist | BFF 패턴 보장 |
| WebFetch 완료 | `praetorian_compact` | 외부 정보 압축 저장 |
| **🔥 Task 완료** | `praetorian_compact` | 세션 간 컨텍스트 보존 |
| **🔥 세션 종료/핸드오프** | `/handoff` (6-Bucket 구조) | decisions/artifacts/problems/facts/issues/next로 구조화 압축 |
| **🔥 규칙 위반/반복 실수/새 패턴** | `/compound` → docs/solutions/ | 트리거: ①CLAUDE.md 규칙 위반 발견 ②같은 실수 2회+ ③camelCase↔snake_case 같은 반복 패턴 |
| 중요 결정 | `serena/write_memory` | 아키텍처 결정 영구 기록 |
| **🔥 사용자 선호도/패턴 발견** | `orbit-memory/memory_save` | AI Agent와 양방향 동기화 |
| 과거 결정/선호도 질문 | `orbit-memory/memory_search` | "이전에 ~가 어떻다고 했지?" |
| 수정 2회+ 실패 | Codex/Gemini delegate (Task) | 근본 원인 파악 |
| **🔥 UI 개선** | `.claude/guides/UI_PATTERNS.md` | 디자인 시스템 일관성 |
| **🔥 커밋/푸시 후** | `Monitor` (CI/ArgoCD 이벤트 감지, 권장) 또는 `deployment-watcher` (레거시) | 배포 상태 추적 |
