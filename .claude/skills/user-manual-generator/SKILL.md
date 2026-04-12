---
name: manual
description: "MCP-Orbit 사용자 매뉴얼 마크다운 자동 생성"
effort: medium
---

# /manual

MCP-Orbit 사용자 매뉴얼을 **마크다운 중심**으로 자동 생성하는 스킬입니다.

## 핵심 워크플로우

```
📝 마크다운 (시작점 & 최종문서)
        ↓
   시나리오 녹화
        ↓
   Claude 분석 & 편집
        ↓
   GIF 생성
        ↓
📝 마크다운 업데이트 (반복)
```

## 사용법

```bash
# 1. 마크다운 매뉴얼 생성/확인
/manual init consumer          # Consumer 매뉴얼 초기화
/manual status consumer        # 진행 상황 확인

# 2. 특정 섹션 녹화 & 편집
/manual record 01-sso-login    # 시나리오 녹화
/manual edit 01-sso-login      # Claude 분석 기반 편집

# 3. 마크다운 업데이트
/manual update consumer        # GIF 삽입 및 상태 업데이트
```

## 워크플로우 상세

### Step 0: 마크다운 매뉴얼 (시작점)

`manual-composer.md` 참조

- 목차와 섹션 구조 먼저 작성
- GIF 자리는 placeholder로 표시: `<!-- GIF: scenario-id | status: pending -->`
- 진행하면서 업데이트하는 **Living Document**

### Step 1: 시나리오 녹화

`screen-recorder.md` + `scenario-executor.md` 참조

- Chrome DevTools MCP로 브라우저 자동화
- ffmpeg avfoundation으로 화면 녹화

### Step 2: 영상 분석 & 편집

`video-editor.md` 참조

- **Claude가 프레임 이미지를 직접 분석**
- 화면 변화 감지하여 필요 구간 자동 결정
- 불필요한 대기 시간 제거 (70-80% 압축)
- 자막 및 효과 적용

### Step 3: GIF 생성

`gif-generation` 스킬 참조

- palette 기반 고품질 GIF 변환
- 최적화된 파일 크기

### Step 4: 마크다운 업데이트

- placeholder → 실제 GIF 경로
- status: pending → completed
- 필요시 설명 텍스트 보완

## 페르소나별 매뉴얼

| 페르소나 | 대상 | 주요 시나리오 |
|----------|------|---------------|
| Consumer | 일반 사용자 | 로그인, 마켓플레이스, 구독, API 키 |
| Provider | MCP 제공자 | 서버 등록, 도구 정의, 배포 |
| Admin | 관리자 | 팀 관리, 모니터링, 설정 |

## 출력 구조

```
docs/manuals/output/
├── consumer/
│   ├── USER_MANUAL.md           # 메인 매뉴얼
│   ├── 01-sso-login-final.gif
│   ├── 01-sso-login-final.mp4
│   ├── 03-browse-marketplace-final.gif
│   └── ...
├── provider/
│   └── ...
└── admin/
    └── ...
```

## 서브 스킬

| 스킬 | 역할 |
|------|------|
| `manual-composer.md` | 마크다운 매뉴얼 구조 & 워크플로우 |
| `screen-recorder.md` | macOS 화면 녹화 |
| `scenario-executor.md` | Chrome DevTools 시나리오 실행 |
| `video-editor.md` | Claude 프레임 분석 & 영상 편집 |
| `caption-generator.md` | 자막 생성 |
| `video-annotator.md` | zoom/박스 효과 |

## 시나리오 정의

`docs/manuals/scenarios/` 폴더에 JSON 형식으로 정의:

```
docs/manuals/scenarios/
├── INDEX.md                    # 시나리오 목록
├── consumer/
│   ├── 01-sso-login.json
│   ├── 03-browse-marketplace.json
│   └── ...
├── provider/
│   └── ...
└── admin/
    └── ...
```

## 주의사항

- macOS 전용 (avfoundation 사용)
- Chrome이 실행 중이어야 함
- 마크다운이 **진실의 원천(Source of Truth)**
- GIF 완료 전까지 placeholder 유지
