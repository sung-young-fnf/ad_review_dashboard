# Squad Quality Gate — 표준 Binary Eval Set

> quality-squad의 통과/실패 판정을 주관적 판단에서 정량 eval로 전환.
> 모든 Squad의 구현 완료 검증에 이 eval set을 표준으로 적용.

---

## 표준 Quality Gate Eval (6개)

```
EVAL 1: 빌드 통과
Question: pnpm build && pnpm tsc --noEmit가 에러 0개로 통과하는가?
Pass: 빌드 + 타입체크 모두 성공
Fail: 1개 이상 에러

EVAL 2: AC 100% 달성
Question: Task의 모든 Acceptance Criteria 체크박스가 ✅인가?
Pass: 모든 AC 체크박스 완료
Fail: 1개 이상 미완료 AC

EVAL 3: Scope 준수
Question: git diff --name-only가 Task/Story 범위 내 파일만 포함하는가?
Pass: 변경 파일 모두 Task scope 내
Fail: 범위 밖 파일 변경 (scope creep)

EVAL 4: Full-Stack 완전성
Question: feat 커밋에 Backend + BFF + Frontend가 모두 포함되었는가?
Pass: 3레이어 모두 포함 (또는 해당 없음 사유 명시)
Fail: 한쪽만 구현 후 "완료" 보고

EVAL 5: 보안 체크
Question: OWASP Top 10 위반이 없는가? (SQL injection, XSS, 하드코딩된 시크릿 등)
Pass: 보안 취약점 0개
Fail: 1개 이상 보안 위반

EVAL 6: OpenAPI 동기화
Question: Backend DTO 변경 시 OpenAPI 타입이 재생성되었는가?
Pass: DTO 변경 없음 또는 재생성 완료
Fail: DTO 변경했으나 OpenAPI 미재생성
```

---

## 적용 방법

### quality-squad Lead가 자동 체크

```markdown
## Quality Gate Report

| Eval | Result | Note |
|------|--------|------|
| 빌드 통과 | ✅/❌ | |
| AC 달성 | ✅/❌ | 미완료: [목록] |
| Scope 준수 | ✅/❌ | 범위 밖: [파일] |
| Full-Stack | ✅/❌ | 누락: [레이어] |
| 보안 | ✅/❌ | 위반: [항목] |
| OpenAPI | ✅/❌ | |

**Pass Rate:** [X]/6 ([Y]%)
**판정:** PASS (6/6) / CONDITIONAL (4-5/6) / FAIL (0-3/6)
```

### 판정 기준

| Pass Rate | 판정 | 행동 |
|-----------|------|------|
| 6/6 (100%) | **PASS** | 완료 승인 |
| 4~5/6 (67~83%) | **CONDITIONAL** | 실패 항목 수정 후 재검증 |
| 0~3/6 (0~50%) | **FAIL** | error-fixer 즉시 위임 |

---

## ai-agent 채팅 품질 Eval (추가)

ai-agent 채팅 서비스 품질 벤치마크용:

```
EVAL C1: 한국어 응답
Question: 채팅 응답이 한국어로 작성되었는가?
Pass: 전체 응답이 한국어 (기술 용어 제외)
Fail: 영어 또는 혼합 언어 응답

EVAL C2: Tool 호출 성공
Question: 필요한 tool_call이 올바르게 실행되었는가?
Pass: tool_call 결과가 정상 반환
Fail: tool_call 실패 또는 누락

EVAL C3: Hallucination 없음
Question: 응답에 존재하지 않는 기능/API/파일을 언급하지 않았는가?
Pass: 모든 참조가 실제 존재하는 것
Fail: 가상의 엔드포인트, 존재하지 않는 함수 등 언급

EVAL C4: 컨텍스트 유지
Question: 이전 대화 내용을 정확히 참조하고 있는가?
Pass: 이전 턴의 정보를 올바르게 기억/참조
Fail: 이전 대화 내용을 잊거나 잘못 참조

EVAL C5: Streaming 완전성
Question: SSE 스트리밍이 중간에 끊기지 않고 완료되었는가?
Pass: [DONE] 시그널까지 정상 전송
Fail: 중간 끊김 또는 [DONE] 미도달
```
