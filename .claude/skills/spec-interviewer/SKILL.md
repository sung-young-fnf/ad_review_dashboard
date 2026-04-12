---
name: spec-interviewer
user-invocable: true
agent: "00-initialization/spec-interviewer"
effort: high
description: |
  SPEC 문서 기반 심층 인터뷰어.
  기술 구현, UI/UX, 우려사항, 트레이드오프 모든 측면을 심층 탐색.

  Triggers: spec interview, deep interview, requirement gathering, context sharing

  Use when: 새 프로젝트 시작, 복잡한 요구사항, 사용자 머릿속 맥락 공유 필요
category: requirements
tags: [spec, interview, requirements, context, epic]
tools: [Read, Write, AskUserQuestion, mcp__serena__write_memory]
complexity: medium
estimated_tokens: 2000
progressive_loading: false
---

# Spec Interviewer Skill

SPEC.md를 읽고 AskUserQuestion으로 심층 인터뷰를 진행하여
사용자 머릿속의 모든 프로젝트 맥락을 수집합니다.

## 사용법

```bash
/spec-interview              # SPEC.md 기반 인터뷰 시작
/spec-interview docs/my-spec.md  # 특정 파일 기반 인터뷰
```

## 인터뷰 카테고리

1. **비즈니스 컨텍스트**: 핵심 문제, 타겟 사용자, KPI
2. **기술 구현**: 기술 스택, 외부 연동, 성능 요구
3. **UI/UX**: 디자인 참조, 모바일, 접근성
4. **우려사항**: 보안, 규제, 기술 리스크
5. **트레이드오프**: 시간 vs 품질, MVP 범위

## 인터뷰 전략

### Round 1 (핵심 4개 질문)
- 핵심 비즈니스 문제
- MVP 범위
- 주요 리스크
- 시간 vs 품질 트레이드오프

### Round 2+ (심화 질문)
Round 1 답변이 모호하거나 추가 탐색이 필요한 경우:
- 구체화 질문
- 옵션 제시 질문
- 기술 의사결정 질문

### 종료 조건
- confidence >= 90%
- 최대 3라운드 (12개 질문)
- 사용자 조기 종료 선택

## 출력물

### 1. enriched-spec.md
인터뷰로 보강된 상세 스펙 문서
- 위치: `docs/specs/enriched-spec.md`
- 내용: 비즈니스 컨텍스트, 기술 결정, MVP 범위, 리스크

### 2. Serena Memory
영구 저장 (epic-creator 참조용)
- identifier: `spec_interview_{project_name}`

## 다음 단계

인터뷰 완료 후 자동으로 epic-creator 호출 또는:

```bash
/epic-creator:create enriched-spec.md
```

## 참조

- **에이전트 상세**: @.claude/agents/00-initialization/spec-interviewer.md
- **Epic 생성**: @.claude/agents/02-requirements/epic-creator.md
- **Quality Standards**: @.claude/rules/quality-standards.md
