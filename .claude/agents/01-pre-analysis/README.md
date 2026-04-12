# 📋 사전분석 Agent 실행 가이드

## 🎯 목적

프로젝트의 AI 코딩 파트너 활용을 위한 체계적인 사전분석을 수행합니다.

---

## 🚀 빠른 시작 (Quick Start)

### { } 서비스 사전분석 예시

```bash
"{ } 서비스의 AI 코딩을 위해 사전분석을 시작합니다.
다음 6개 Agent를 병렬로 실행하여 docs/ 하위 폴더에 결과를 저장해주세요:

1. code-structure-analyzer - 코드 구조와 의존성 파악
2. tech-stack-analyzer - 기술 스택과 프레임워크 분석
3. code-quality-inspector - 코드 품질과 보안 취약점 검사
4. business-analyzer - 비즈니스 도메인과 규칙 이해
5. comprehensive-db-analyzer - 데이터베이스 구조와 관계 분석
6. test-env-analyzer - 테스트 환경과 패턴 분석 (test-creator 전제조건)

각 Agent는 독립적으로 실행되며, 결과는 docs/ 하위 적절한 폴더에 자동 저장됩니다."
```

---

## 📊 단계별 실행 가이드

### Phase 1: 준비 단계 (1분)

```bash
# 1. 프로젝트 루트 확인
"현재 프로젝트 루트 디렉토리를 확인해주세요"

# 2. Agent 파일 복사 확인
"/.claude/agents/01-pre-analysis/ 폴더에 모든 Agent 파일이 있는지 확인해주세요"

# 3. 출력 디렉토리 생성
"다음 디렉토리를 생성해주세요:
- docs/analysis/
- docs/quality/
- docs/database/
- .claude/temp/
- .claude/memories/"
```

### Phase 2: 병렬 분석 실행 (5-10분)

```bash
"다음 6개 Agent를 병렬로 실행해주세요:

*parallel [
  '01-pre-analysis/code-structure-analyzer',
  '01-pre-analysis/tech-stack-analyzer',
  '01-pre-analysis/code-quality-inspector',
  '01-pre-analysis/business-analyzer',
  '01-pre-analysis/db-analyzer',
  '01-pre-analysis/test-env-analyzer'
]

각 Agent가 완료되면 자동으로 결과 파일이 생성됩니다."
```

### Phase 3: 결과 통합 (2분)

```bash
"모든 분석이 완료되면 다음을 확인해주세요:

생성된 파일들:
- docs/analysis/code-structure.md
- docs/analysis/tech-stack.md
- docs/quality/code-quality-report.md
- docs/analysis/business-domain.md
- docs/database/comprehensive-analysis.md
- docs/analysis/test-environment.md

통합 리포트를 생성하려면:
*task report-generator --type comprehensive"
```

---

## 🎨 프로젝트별 맞춤 가이드

### 1. E-Commerce 프로젝트

```bash
"이커머스 프로젝트 분석을 시작합니다.
중점 분석 영역: 결제 보안, 재고 관리, 주문 처리 흐름

다음 Agent들을 순서대로 실행해주세요:
1. business-analyzer --focus payment,inventory,order
2. db-analyzer --focus transactions
3. code-quality-inspector --focus security
4. tech-stack-analyzer
5. code-structure-analyzer --path src/api/"
```

### 2. SaaS 플랫폼

```bash
"SaaS 플랫폼 분석을 시작합니다.
중점 분석 영역: 멀티테넌시, 권한 관리, API 설계

병렬 실행 Agent:
- business-analyzer --focus multi-tenancy
- code-structure-analyzer --depth 2
- tech-stack-analyzer --include-infra
- code-quality-inspector --focus auth
- db-analyzer --focus tenant-isolation"
```

### 3. 레거시 시스템 현대화

```bash
"레거시 시스템 현대화를 위한 분석을 시작합니다.
중점 분석 영역: 기술 부채, 마이그레이션 리스크, 리팩토링 우선순위

순차 실행 권장:
1. tech-stack-analyzer --detect-legacy
2. code-quality-inspector --mode deep
3. code-structure-analyzer --find-circular
4. db-analyzer --check-normalization
5. business-analyzer --extract-rules"
```

---

## 🔧 고급 실행 옵션

### 선택적 분석 (특정 영역만)

```bash
# 보안 중심 분석
"보안 취약점 분석에 집중합니다:
*task 01-pre-analysis/code-quality-inspector --focus security --mode deep"

# 성능 중심 분석
"성능 병목점 분석에 집중합니다:
*task 01-pre-analysis/code-quality-inspector --focus performance
*task 01-pre-analysis/db-analyzer --check-indexes"

# 아키텍처 중심 분석
"시스템 아키텍처 분석에 집중합니다:
*task 01-pre-analysis/code-structure-analyzer --depth 3
*task 01-pre-analysis/tech-stack-analyzer --include-patterns"
```

### 증분 분석 (변경된 부분만)

```bash
"최근 변경사항만 분석합니다:
*parallel [
  '01-pre-analysis/code-structure-analyzer --incremental',
  '01-pre-analysis/code-quality-inspector --changed-only'
]"
```

### 심층 분석 (상세 모드)

```bash
"전체 프로젝트를 심층 분석합니다 (15-20분 소요):
*parallel [
  '01-pre-analysis/code-structure-analyzer --depth 3 --timeout 600000',
  '01-pre-analysis/tech-stack-analyzer --deep --timeout 600000',
  '01-pre-analysis/code-quality-inspector --mode deep --timeout 600000',
  '01-pre-analysis/business-analyzer --comprehensive --timeout 600000',
  '01-pre-analysis/db-analyzer --full-scan --timeout 600000'
]"
```

---

## 📁 결과물 구조

### 생성되는 파일들

```
docs/                           # 프로젝트 표준 산출물 위치
├── analysis/                   # 분석 산출물
│   ├── code-structure.md      # 코드 구조 분석
│   ├── tech-stack.md          # 기술 스택 분석
│   ├── business-domain.md     # 비즈니스 도메인 분석
│   └── test-environment.md    # 테스트 환경 분석
│
├── quality/                    # 품질 관련 산출물
│   ├── code-quality-report.md # 코드 품질 보고서
│   └── code-metrics.json      # 정량적 메트릭스
│
└── database/                   # DB 관련 산출물
    ├── comprehensive-analysis.md # DB 종합 분석
    ├── erd-mermaid.mmd         # ERD 다이어그램
    ├── crud-matrix.csv         # CRUD 매트릭스
    └── data-dictionary.md      # 데이터 사전

.claude/                        # Claude 전용 작업 공간
├── temp/                       # 임시 작업 파일
│   └── [agent-name]-temp.json
│
└── memories/                   # Serena MCP 메모리
    └── [analysis-name]-[timestamp]
```

---

## ✅ 체크리스트

### 실행 전 확인사항

- [ ] 프로젝트 루트 디렉토리에서 실행
- [ ] `.claude/agents/01-pre-analysis/` 폴더 존재
- [ ] 필요한 디렉토리 생성 완료
- [ ] Git 저장소인 경우 `.gitignore`에 `.claude/temp/` 추가

### 실행 중 모니터링

- [ ] 각 Agent 실행 상태 확인
- [ ] 에러 발생 시 개별 재실행
- [ ] 메모리/CPU 사용량 모니터링

### 실행 후 검증

- [ ] 모든 결과 파일 생성 확인
- [ ] 분석 결과 일관성 검토
- [ ] 다음 단계 Agent 준비

---

## 🚨 문제 해결

### Agent 실행 실패 시

```bash
# 개별 Agent 재실행
"[agent-name] 실행이 실패했습니다. 다시 실행합니다:
*task 01-pre-analysis/[agent-name] --retry"

# 로그 확인
"실행 로그를 확인합니다:
*read .claude/logs/[agent-name].log"
```

### Serena MCP 연결 실패 시

```bash
"Serena MCP를 사용할 수 없습니다. 기본 모드로 실행합니다:
*task 01-pre-analysis/code-structure-analyzer --mode basic"
```

### 메모리 부족 시

```bash
"메모리 사용량을 줄여 실행합니다:
*task 01-pre-analysis/code-quality-inspector --limit-files 10"
```

---

## 💡 Best Practices

### 1. 병렬 실행 활용

- 독립적인 Agent들은 항상 병렬로 실행
- 5개 Agent 병렬 실행 시 약 70% 시간 단축

### 2. 점진적 분석

- 큰 프로젝트는 모듈별로 나누어 분석
- 핵심 모듈부터 우선 분석

### 3. 결과 버전 관리

```bash
# 분석 결과를 Git에 커밋
"분석 결과를 저장합니다:
git add docs/analysis/*.md docs/quality/*.md docs/database/*.md
git commit -m 'chore: add pre-analysis results for AI coding partner'"
```

### 4. 팀 공유

```bash
# 팀원과 분석 결과 공유
"분석 결과를 팀과 공유합니다:
*task report-generator --format team-summary
*share docs/team-summary.pdf"
```

---

## 📈 예상 소요 시간

| 프로젝트 규모 | 파일 수 | 병렬 실행 | 순차 실행 |
| ------------- | ------- | --------- | --------- |
| 소규모        | < 100   | 3-5분     | 10-15분   |
| 중규모        | 100-500 | 5-10분    | 20-30분   |
| 대규모        | > 500   | 10-15분   | 30-45분   |

---

## 🎯 다음 단계

사전분석 완료 후:

1. **요구사항 분석**: `02-requirements/` Agent 실행
2. **설계 단계**: `03-design/` Agent 실행
3. **구현 단계**: `04-implementation/` Agent 실행
4. **테스트 단계**: `05-testing/` Agent 실행

---

## 📞 지원

문제 발생 시:

- Agent 관련: `.claude/agents/README.md` 참조
- 실행 오류: `.claude/logs/` 확인
- 추가 지원: F&F AI Team 문의

---

**Version**: 1.0.0  
**Last Updated**: 2025-01-18  
**Author**: F&F AI Coding Partner Team
