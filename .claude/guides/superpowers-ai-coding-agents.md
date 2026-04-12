# Superpowers: AI Coding Agents 가이드

> 출처: https://blog.fsck.com/2025/10/09/superpowers/
> 2025년 10월 기준 AI 코딩 에이전트 활용 가이드

## 개요

"Superpowers"는 AI 코딩 에이전트(특히 Claude)에게 향상된 능력을 부여하는 스킬 기반 시스템입니다. 마크다운 문서로 정의된 스킬을 통해 AI 에이전트가 학습하고, 생성하고, 개선할 수 있는 체계적인 접근 방식을 제공합니다.

## 핵심 개념: Skills as Superpowers

### Skills란?

- **정의**: AI 에이전트에게 특정 능력을 부여하는 마크다운 문서
- **특징**:
  - 스킬이 존재하면 필수적으로 적용됨
  - 구체적인 지침과 제약사항 제공
  - 테스트, 개선, 공유 가능

### Skills의 장점

1. **재사용성**: 한 번 정의하면 여러 프로젝트에서 활용
2. **일관성**: 표준화된 방식으로 작업 수행
3. **진화**: 시간이 지남에 따라 개선 가능
4. **신뢰성**: 더 규율적이고 안정적인 AI 엔지니어링

## 워크플로우 진화

### Brainstorm → Plan → Implement

```
브레인스토밍 → 계획 수립 → 구현
```

**주요 기능:**
- 자동 git worktree 생성으로 병렬 작업 지원
- RED/GREEN Test-Driven Development (TDD) 접근
- 작업 구현 및 코드 리뷰 옵션 제공

### 자동화된 워크플로우

1. **병렬 작업**: Git worktree로 여러 태스크 동시 처리
2. **TDD 사이클**:
   - RED: 실패하는 테스트 작성
   - GREEN: 테스트 통과하는 최소 코드 구현
   - REFACTOR: 코드 개선

## Skill 개발 기법

### 1. 문서/책에서 스킬 추출

- 전문 서적이나 문서를 읽고 재사용 가능한 스킬로 변환
- 예: Robert Cialdini의 설득 원리를 에이전트 신뢰성 향상에 활용

### 2. Pressure Testing

서브에이전트 시나리오를 통한 스킬 검증:

**테스트 시나리오:**
- **시간 압박 시나리오**: 긴급 상황에서의 에이전트 행동 검증
- **매몰 비용 시나리오**: 이미 투자한 작업에 대한 판단력 검증
- **준수도 테스트**: 에이전트가 지침을 올바르게 이해하고 따르는지 확인

### 3. 설득 원리 활용

AI 에이전트 신뢰성 향상을 위한 설득 기법:
- 일관성 원칙
- 사회적 증거
- 권위
- 호감
- 희소성
- 상호성

## 기술적 구현

### 설치 방법

```bash
# Claude Code 플러그인 마켓플레이스에 추가
/plugin marketplace add obra/superpowers-marketplace

# Superpowers 플러그인 설치
/plugin install superpowers@superpowers-marketplace
```

### 프로젝트 구조

```
.claude/
├── skills/           # 스킬 정의 디렉토리
│   ├── skill1.md
│   └── skill2.md
└── memories/         # 대화 기록 메모리
```

## 향후 개발 방향

### 1. Sharing (공유 메커니즘)

**목표**: 안전한 스킬 공유 시스템 구축

**고려사항:**
- 보안: 민감한 정보 노출 방지
- 품질 관리: 검증된 스킬만 공유
- 버전 관리: 스킬 업데이트 추적

### 2. Memories (메모리 시스템)

**목표**: 과거 대화 기록을 활용하는 시스템

**기능:**
- 이전 대화에서 학습
- 반복되는 패턴 인식
- 프로젝트별 컨텍스트 유지

## 기술적 영향

### 주요 영향 요소

1. **Microsoft Amplifier Framework**
   - 체계적인 AI 에이전트 구조화 방법론

2. **Robert Cialdini의 설득 연구**
   - AI 에이전트 신뢰성 향상 원리

3. **Anthropic의 Claude Code 플러그인 시스템**
   - 확장 가능한 에이전트 아키텍처

## 실전 활용 예시

### Skill 작성 예시

```markdown
# Skill: TDD Implementation

## 목표
테스트 주도 개발 방식으로 코드 작성

## 단계
1. RED: 실패하는 테스트 먼저 작성
2. GREEN: 테스트를 통과하는 최소한의 코드 구현
3. REFACTOR: 코드 품질 개선

## 제약사항
- 테스트 없이 구현 코드 작성 금지
- 테스트가 통과하기 전까지 다음 기능 작업 금지

## 검증
- 모든 테스트가 통과하는지 확인
- 코드 커버리지 80% 이상 유지
```

### Pressure Testing 예시

```markdown
# 시나리오: 긴급 버그 수정

## 상황
프로덕션에서 치명적인 버그 발견. 30분 내 수정 필요.

## 테스트 목표
- 에이전트가 패닉하지 않고 체계적으로 접근하는가?
- 필수 테스트를 건너뛰지 않는가?
- 빠른 수정과 안전한 수정 사이에서 올바른 판단을 하는가?

## 성공 기준
- TDD 원칙 준수
- 테스트 커버리지 유지
- 체계적인 디버깅 프로세스 수행
```

## 모범 사례

### DO ✅

1. **명확한 스킬 정의**
   - 목표, 단계, 제약사항 명시
   - 구체적인 예시 포함

2. **반복적인 개선**
   - Pressure testing으로 스킬 검증
   - 피드백 기반 지속적 개선

3. **문서화**
   - 스킬의 목적과 사용법 명확히 기록
   - 변경 이력 추적

### DON'T ❌

1. **너무 일반적인 스킬**
   - 구체성 부족 → 효과 감소
   - 명확한 가이드라인 없음

2. **테스트하지 않은 스킬**
   - 실제 상황에서 작동하지 않을 수 있음
   - 예상치 못한 부작용 가능

3. **과도한 복잡성**
   - 에이전트가 이해하기 어려움
   - 유지보수 부담 증가

## 결론

"Superpowers"는 AI 코딩 에이전트를 더 똑똑하고 적응력 있게 만드는 스킬 기반 접근 방식입니다. 체계적인 스킬 개발과 테스팅을 통해 더 신뢰할 수 있는 AI 엔지니어링 파트너를 만들 수 있습니다.

### 핵심 메시지

> "Skills are what give your agents Superpowers."
>
> 스킬이 당신의 에이전트에게 슈퍼파워를 부여합니다.

## 참여 방법

### 시작하기

1. Claude Code 플러그인으로 설치
2. 스킬 생성 실험
3. 오픈 저장소에 기여

### 기여하기

- GitHub에서 버그 리포트
- 새로운 스킬 Pull Request 제출
- 커뮤니티와 경험 공유

## 참고 자료

- GitHub Repository: obra/superpowers-marketplace
- Claude Code Plugin System
- Microsoft Amplifier Framework
- Robert Cialdini - Influence: The Psychology of Persuasion

---

**마지막 업데이트**: 2025년 10월
**원문**: https://blog.fsck.com/2025/10/09/superpowers/
