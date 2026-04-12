---
name: claude-hud
# Claude Code 2.1.0: Skills → Slash Command 통합
user-invocable: true
effort: low
description: |
  Configure claude-hud as your statusline with context window monitoring.
  Set up custom presets for different workflows.

  Triggers: statusline setup, hud config, context monitor

  Use when: setting up status line display, monitoring context window usage
category: configuration
tags: [statusline, hud, monitoring, context-window]
tools:
  - Read
  - Edit
complexity: low
estimated_tokens: 300
progressive_loading: false
---

# Claude HUD Configuration Skill

Configure claude-hud statusline with context window monitoring and custom presets.

## Overview

This skill helps you set up and customize the claude-hud statusline to monitor context window usage, current model, and session status. It leverages Claude Code 2.1.0's status line features.

## Available Status Fields

### Context Window Monitoring

```yaml
# context_window 필드 활용
context_window:
  used_percentage: 45.2      # 현재 사용률 (%)
  total_tokens: 200000       # 모델의 최대 토큰
  used_tokens: 90400         # 현재 사용 토큰
  remaining_tokens: 109600   # 남은 토큰
```

### Current Usage

```yaml
# current_usage 필드 활용
current_usage:
  input_tokens: 45000        # 입력 토큰
  output_tokens: 12000       # 출력 토큰
  cache_read_tokens: 8000    # 캐시 읽기 토큰
  cache_write_tokens: 2000   # 캐시 쓰기 토큰
```

## Preset Configurations

### 1. Minimal (기본)

```bash
# 최소한의 정보만 표시
claude config set statusLine.format "{{model}} | {{context_percentage}}%"
```

출력 예: `opus-4-5 | 45%`

### 2. Developer (개발자용)

```bash
# 세션 + 컨텍스트 + 모델
claude config set statusLine.format "{{session_id}} | {{model}} | {{context_percentage}}% ({{remaining_tokens}})"
```

출력 예: `epic-EP032 | opus-4-5 | 45% (109.6K)`

### 3. Monitor (모니터링용)

```bash
# 상세 토큰 사용량
claude config set statusLine.format "In:{{input_tokens}} Out:{{output_tokens}} Cache:{{cache_read_tokens}} | {{context_percentage}}%"
```

출력 예: `In:45K Out:12K Cache:8K | 45%`

### 4. Warning (경고 포함)

```bash
# 컨텍스트 80% 이상 시 경고
claude config set statusLine.warningThreshold 80
claude config set statusLine.format "{{model}} | {{context_percentage}}% {{#if context_warning}}[!]{{/if}}"
```

출력 예: `opus-4-5 | 85% [!]`

## Custom Preset Setup

### Step 1: 설정 파일 위치 확인

```bash
# 전역 설정
~/.config/claude/settings.json

# 프로젝트별 설정
.claude/settings.json
```

### Step 2: settings.json 수정

```json
{
  "statusLine": {
    "enabled": true,
    "format": "{{session_id}} | {{model}} | {{context_percentage}}%",
    "refreshInterval": 5000,
    "warningThreshold": 80,
    "presets": {
      "minimal": "{{model}} | {{context_percentage}}%",
      "developer": "{{session_id}} | {{model}} | {{context_percentage}}%",
      "monitor": "In:{{input_tokens}} Out:{{output_tokens}} | {{context_percentage}}%"
    }
  }
}
```

### Step 3: 프리셋 전환

```bash
# 프리셋 적용
claude config set statusLine.preset minimal
claude config set statusLine.preset developer
claude config set statusLine.preset monitor
```

## Process

### Step 1: 현재 설정 확인

```bash
# 현재 statusLine 설정 확인
claude config get statusLine
```

### Step 2: 프리셋 선택

사용자 워크플로우에 맞는 프리셋 선택:
- **minimal**: 간단한 작업, 화면 공간 절약
- **developer**: Epic/Story 작업, 세션 추적 필요
- **monitor**: 대용량 분석, 토큰 사용량 모니터링

### Step 3: 적용 및 확인

```bash
# 설정 적용
claude config set statusLine.format "선택한 프리셋 포맷"

# 적용 확인
claude config get statusLine.format
```

## Exit Criteria

- [ ] statusLine 설정 파일 위치 확인됨
- [ ] 사용자 요구에 맞는 프리셋 선택됨
- [ ] 설정 적용 완료
- [ ] 적용 결과 확인됨

## Troubleshooting

### statusLine이 표시되지 않음

```bash
# 활성화 확인
claude config set statusLine.enabled true
```

### 포맷 오류

```bash
# 기본값으로 리셋
claude config set statusLine.format "{{model}} | {{context_percentage}}%"
```

### 새로고침 빈도 조정

```bash
# 5초마다 새로고침 (기본: 10초)
claude config set statusLine.refreshInterval 5000
```
