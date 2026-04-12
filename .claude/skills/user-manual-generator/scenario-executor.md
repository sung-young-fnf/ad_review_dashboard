# 시나리오 실행 서브에이전트

Chrome DevTools MCP를 사용하여 시나리오를 자동 실행하는 서브에이전트입니다.

## 역할

1. 시나리오 JSON 파싱
2. Chrome DevTools MCP 도구로 각 단계 실행
3. 각 단계의 요소 좌표 수집 (효과 적용용)
4. 타이밍 정보 기록

## Chrome DevTools MCP 도구 매핑

| 시나리오 action | MCP 도구 | 설명 |
|----------------|---------|------|
| `navigate` | `navigate_page` | URL 이동 |
| `click` | `click` | 요소 클릭 |
| `type` | `fill` | 텍스트 입력 |
| `hover` | `hover` | 마우스 오버 |
| `scroll` | `evaluate_script` | 스크롤 실행 |
| `wait` | (sleep) | 대기 |
| `screenshot` | `take_screenshot` | 스크린샷 |

## 실행 워크플로우

### 1. 페이지 선택/생성

```bash
# 기존 Chrome 페이지 목록 확인
mcp-cli call chrome-devtools/list_pages '{}'

# 새 페이지 생성
mcp-cli call chrome-devtools/new_page '{"url": "http://localhost:3000"}'

# 페이지 선택
mcp-cli call chrome-devtools/select_page '{"index": 0}'
```

### 2. 시나리오 단계 실행

#### navigate (페이지 이동)

```bash
mcp-cli call chrome-devtools/navigate_page '{"url": "http://localhost:3000/login"}'
```

#### click (요소 클릭)

```bash
# 먼저 스냅샷으로 요소 UID 확인
mcp-cli call chrome-devtools/take_snapshot '{}'

# UID로 클릭
mcp-cli call chrome-devtools/click '{"uid": "element-uid-123"}'
```

#### fill (텍스트 입력)

```bash
mcp-cli call chrome-devtools/fill '{"uid": "input-uid-456", "value": "user@example.com"}'
```

#### hover (마우스 오버)

```bash
mcp-cli call chrome-devtools/hover '{"uid": "menu-uid-789"}'
```

#### wait (대기)

```bash
# JavaScript로 대기 또는 특정 요소 대기
mcp-cli call chrome-devtools/wait_for '{"selector": ".loading", "state": "hidden", "timeout": 5000}'
```

#### screenshot (스크린샷)

```bash
mcp-cli call chrome-devtools/take_screenshot '{"filePath": "output/step_1.png", "fullPage": false}'
```

### 3. 요소 좌표 수집

효과 적용을 위해 각 클릭 요소의 좌표를 수집합니다:

```bash
# JavaScript로 요소 좌표 가져오기
mcp-cli call chrome-devtools/evaluate_script '{
  "script": "
    const el = document.querySelector(\"#login-button\");
    const rect = el.getBoundingClientRect();
    JSON.stringify({
      x: Math.round(rect.x),
      y: Math.round(rect.y),
      width: Math.round(rect.width),
      height: Math.round(rect.height)
    });
  "
}'
```

## 시나리오 실행 예시

### 입력 시나리오

```json
{
  "title": "로그인 튜토리얼",
  "baseUrl": "http://localhost:3000",
  "steps": [
    {
      "action": "navigate",
      "url": "/login",
      "caption": "로그인 페이지로 이동합니다",
      "duration": 2
    },
    {
      "action": "click",
      "selector": "#email",
      "caption": "이메일 입력란을 클릭합니다",
      "duration": 1.5,
      "highlight": { "type": "box", "color": "red" }
    },
    {
      "action": "type",
      "selector": "#email",
      "text": "demo@example.com",
      "caption": "이메일을 입력합니다",
      "duration": 2
    },
    {
      "action": "click",
      "selector": "button[type=submit]",
      "caption": "로그인 버튼을 클릭합니다",
      "duration": 1.5,
      "zoom": { "scale": 1.5 }
    }
  ]
}
```

### 실행 출력

```json
{
  "title": "로그인 튜토리얼",
  "totalDuration": 7,
  "executedSteps": [
    {
      "index": 0,
      "action": "navigate",
      "startTime": 0,
      "endTime": 2,
      "status": "success"
    },
    {
      "index": 1,
      "action": "click",
      "startTime": 2,
      "endTime": 3.5,
      "elementCoords": { "x": 320, "y": 240, "w": 300, "h": 40 },
      "status": "success"
    },
    {
      "index": 2,
      "action": "type",
      "startTime": 3.5,
      "endTime": 5.5,
      "status": "success"
    },
    {
      "index": 3,
      "action": "click",
      "startTime": 5.5,
      "endTime": 7,
      "elementCoords": { "x": 320, "y": 350, "w": 150, "h": 45 },
      "status": "success"
    }
  ]
}
```

## 에러 처리

### 요소를 찾을 수 없음

```bash
# 재시도 로직
for i in {1..3}; do
  result=$(mcp-cli call chrome-devtools/take_snapshot '{}')
  if echo "$result" | grep -q "$SELECTOR"; then
    break
  fi
  sleep 1
done
```

### 페이지 로딩 대기

```bash
# DOM 로딩 완료 대기
mcp-cli call chrome-devtools/wait_for '{"selector": "body", "state": "attached", "timeout": 10000}'
```

### 네트워크 요청 대기

```bash
# 특정 API 호출 완료 대기
mcp-cli call chrome-devtools/wait_for '{"url": "/api/auth/*", "state": "finished"}'
```

## 브라우저 설정

### 창 크기 설정

```bash
mcp-cli call chrome-devtools/resize_page '{"width": 1280, "height": 800}'
```

### 디바이스 에뮬레이션 (모바일)

```bash
mcp-cli call chrome-devtools/emulate '{"device": "iPhone 12"}'
```

## 출력

- 실행 결과 JSON (타이밍, 좌표 정보)
- 각 단계별 스크린샷 (선택적)
- 에러 로그 (실패 시)
