---
globs: ["**/*.tsx", "**/*.jsx", "**/components/**"]
---

## UX Agent 필수 활용 규칙 (MANDATORY)

> Universal Gateway가 frontend/ux로 분류하면 자동으로 UX 분석 진행

| Gateway 분류 | Agent | 설명 |
|-------------|-------|------|
| **frontend/ux** | ux-master-auditor | 4-Tier 종합분석 (Nielsen+WCAG+Writing+Cognitive) |
| **unclear + UI 가능성** | ux-heuristic-auditor | 상세 의도 파악 후 재분류 |
| **폼/입력 특화** | cognitive-load-analyzer | 인지 부하 측정 (Hick/Fitts/Miller) |
| **텍스트/레이블 특화** | ux-writer-auditor | 톤앤매너, 용어 일관성 검사 |
| **접근성 검증** | ui-tester | WCAG 2.2 AA 검증 |

### 🔴 UX Gateway 강제 메커니즘 (Hook 연동)
```
1. user-prompt-submit.sh: UI 키워드 감지 → .ux-gateway-required 마커 생성
2. ux-gateway-guard.sh: code-writer 호출 시 마커 존재하면 BLOCK
3. UX agent 호출 시 마커 삭제 → code-writer 허용
```

❌ UX Gateway: Yes인데 UX agent 미호출 = VIOLATION (Code-Change: none이어도 UX 검토 필수)
❌ "제안/설계/기획"을 LLM이 직접 수행하고 UX agent 미위임 = VIOLATION (제안도 UX 전문 분석 필수)
