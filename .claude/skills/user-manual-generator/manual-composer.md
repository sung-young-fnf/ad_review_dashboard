# Manual Composer Skill

마크다운 매뉴얼이 **시작점이자 최종 산출물**이 되는 워크플로우입니다.

## 핵심 개념

```
┌─────────────────────────────────────────────────────────────────┐
│  0. 📝 마크다운 매뉴얼 (계획 & Living Document)                   │
│     └─ 목차, 섹션 구조, 설명 먼저 작성                           │
│     └─ GIF 자리는 <!-- GIF: scenario-id --> placeholder         │
│                     ↓                                           │
│  1. 시나리오별 녹화 (screen-recorder + scenario-executor)        │
│                     ↓                                           │
│  2. 영상 분석 & 편집 (video-editor)                              │
│     └─ Claude가 프레임 분석하여 자동 구간 결정                    │
│                     ↓                                           │
│  3. GIF 생성 (gif-generation)                                    │
│                     ↓                                           │
│  4. 📝 마크다운 업데이트                                         │
│     └─ placeholder → 실제 GIF 경로                              │
│     └─ 상태: pending → completed                                │
└─────────────────────────────────────────────────────────────────┘
```

## Step 0: 마크다운 매뉴얼 생성

### 템플릿

```markdown
# [서비스명] 사용자 매뉴얼

> 최종 업데이트: YYYY-MM-DD
> 상태: 🔄 작성 중 | ✅ 완료

## 목차

1. [시작하기](#1-시작하기)
2. [기능 A](#2-기능-a)
3. [기능 B](#3-기능-b)
...

---

## 1. 시작하기

### 1.1 로그인

Microsoft SSO를 통해 로그인합니다.

<!-- GIF: 01-sso-login | status: pending -->

**단계:**
1. 로그인 페이지에서 "Microsoft 계정으로 로그인" 클릭
2. Azure AD 인증 완료
3. 프로젝트 목록으로 자동 이동

---

## 2. 기능 A

<!-- GIF: 02-feature-a | status: pending -->

**단계:**
1. ...
2. ...

---
```

### Placeholder 문법

```html
<!-- GIF: {scenario-id} | status: {pending|recording|editing|completed} -->
```

- `scenario-id`: docs/manuals/scenarios/ 폴더의 JSON 파일명 (확장자 제외)
- `status`: 현재 진행 상태

## Step 1: 매뉴얼 파싱 & 진행 상황 확인

```bash
# 마크다운에서 GIF placeholder 추출
grep -n "<!-- GIF:" USER_MANUAL.md
```

출력 예시:
```
15:<!-- GIF: 01-sso-login | status: completed -->
35:<!-- GIF: 03-browse-marketplace | status: completed -->
55:<!-- GIF: 04-subscribe-mcp | status: pending -->
```

## Step 2: 녹화 & 편집 (시나리오별)

pending 상태인 항목에 대해:

1. **시나리오 확인**: `docs/manuals/scenarios/{scenario-id}.json` 읽기
2. **녹화 실행**: `screen-recorder.md` 참조
3. **영상 편집**: `video-editor.md` 참조 (Claude 프레임 분석)
4. **GIF 생성**: `gif-generation` 스킬 참조

## Step 3: 마크다운 업데이트

### GIF 삽입 및 상태 변경

Before:
```markdown
<!-- GIF: 01-sso-login | status: pending -->
```

After:
```markdown
<!-- GIF: 01-sso-login | status: completed -->
![SSO 로그인](./consumer/01-sso-login-final.gif)
```

### 자동 업데이트 스크립트

```bash
# scenario-id와 GIF 경로로 마크다운 업데이트
SCENARIO_ID="01-sso-login"
GIF_PATH="./consumer/01-sso-login-final.gif"
MANUAL_FILE="docs/manuals/output/USER_MANUAL.md"

# placeholder를 실제 이미지로 교체
sed -i '' "s|<!-- GIF: $SCENARIO_ID | status: pending -->|<!-- GIF: $SCENARIO_ID | status: completed -->\n![$SCENARIO_ID]($GIF_PATH)|g" "$MANUAL_FILE"
```

## 진행 상황 대시보드

마크다운 파일 상단에 진행 상황 표시:

```markdown
## 진행 상황

| 섹션 | 시나리오 | 상태 |
|------|----------|------|
| 1.1 로그인 | 01-sso-login | ✅ 완료 |
| 2.1 마켓플레이스 | 03-browse-marketplace | ✅ 완료 |
| 2.2 구독 | 04-subscribe-mcp | 🔄 녹화 중 |
| 3.1 API 키 | 06-manage-api-keys | ⏳ 대기 |
```

## 페르소나별 매뉴얼 구조

```
docs/manuals/output/
├── consumer/                    # Consumer 페르소나
│   ├── USER_MANUAL.md          # 메인 매뉴얼
│   ├── 01-sso-login-final.gif
│   ├── 03-browse-marketplace-final.gif
│   └── ...
├── provider/                    # Provider 페르소나
│   ├── USER_MANUAL.md
│   └── ...
└── admin/                       # Admin 페르소나
    ├── USER_MANUAL.md
    └── ...
```

## Exit Criteria

- [ ] 마크다운 매뉴얼 생성됨
- [ ] 모든 GIF placeholder가 completed 상태
- [ ] 목차와 내용이 일치
- [ ] 이미지 경로가 모두 유효

## 관련 스킬

- `screen-recorder.md`: 화면 녹화
- `scenario-executor.md`: 시나리오 자동 실행
- `video-editor.md`: Claude 프레임 분석 기반 영상 편집
- `caption-generator.md`: 자막 생성
- `gif-generation`: GIF 변환
