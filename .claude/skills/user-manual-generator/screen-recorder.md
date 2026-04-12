# 화면 녹화 서브에이전트

macOS에서 ffmpeg avfoundation을 사용하여 화면을 녹화하는 서브에이전트입니다.

## 역할

Chrome 브라우저 창 또는 전체 화면을 녹화하여 영상 파일로 저장합니다.

## 사전 요구사항 확인

```bash
# ffmpeg 설치 확인
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg not installed"
    echo "Install: brew install ffmpeg"
    exit 1
fi

# avfoundation 디바이스 목록 확인
ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -E "^\[AVFoundation"
```

## 디바이스 인덱스 확인

```bash
# 출력 예시:
# [AVFoundation input device @ 0x...] [0] FaceTime HD Camera
# [AVFoundation input device @ 0x...] [1] Capture screen 0
# [AVFoundation input device @ 0x...] [2] Capture screen 1

# 보통 "Capture screen 0"이 메인 모니터
SCREEN_INDEX=1  # 또는 확인 후 조정
```

## 녹화 명령어

### 전체 화면 녹화

```bash
ffmpeg -f avfoundation \
  -framerate 30 \
  -capture_cursor 1 \
  -i "${SCREEN_INDEX}:none" \
  -c:v libx264 \
  -preset ultrafast \
  -crf 18 \
  -pix_fmt yuv420p \
  "output/recording_$(date +%Y%m%d_%H%M%S).mp4"
```

### 특정 영역 녹화 (crop 사용)

```bash
# Chrome 창 위치/크기 확인 후 crop
ffmpeg -f avfoundation \
  -framerate 30 \
  -capture_cursor 1 \
  -i "${SCREEN_INDEX}:none" \
  -vf "crop=1280:800:100:50" \
  -c:v libx264 \
  -preset ultrafast \
  -crf 18 \
  "output/recording_cropped.mp4"
```

### 마우스 커서 포함

```bash
# -capture_cursor 1: 커서 표시
# -capture_cursor 0: 커서 숨김
```

## 녹화 제어

### 백그라운드 녹화 시작

```bash
# PID 저장하여 나중에 종료
ffmpeg -f avfoundation -framerate 30 -capture_cursor 1 \
  -i "${SCREEN_INDEX}:none" \
  -c:v libx264 -preset ultrafast -crf 18 \
  "output/recording.mp4" &
FFMPEG_PID=$!
echo $FFMPEG_PID > /tmp/ffmpeg_recording.pid
```

### 녹화 종료

```bash
# graceful 종료 (q 키 시뮬레이션)
kill -INT $(cat /tmp/ffmpeg_recording.pid)

# 또는 강제 종료
# kill $(cat /tmp/ffmpeg_recording.pid)
```

## 품질 프리셋

| 용도 | framerate | crf | preset |
|------|-----------|-----|--------|
| 초안/빠른 확인 | 15 | 28 | ultrafast |
| 문서용 GIF | 15 | 23 | fast |
| 고품질 MP4 | 30 | 18 | medium |
| YouTube 업로드 | 60 | 15 | slow |

## 해상도 설정

```bash
# 녹화 후 리사이즈 (더 안정적)
ffmpeg -i input.mp4 -vf "scale=1280:720" output_720p.mp4

# 녹화 시 바로 리사이즈 (CPU 부하 높음)
ffmpeg -f avfoundation -framerate 30 -i "${SCREEN_INDEX}:none" \
  -vf "scale=1280:720" -c:v libx264 output.mp4
```

## 출력

| 항목 | 설명 |
|------|------|
| 파일 경로 | `output/recording_YYYYMMDD_HHMMSS.mp4` |
| 코덱 | H.264 (libx264) |
| 픽셀 포맷 | yuv420p (호환성 최대) |

## 에러 처리

```bash
# 권한 오류 시
# System Preferences > Security & Privacy > Screen Recording
# 에서 Terminal/iTerm 권한 부여 필요

# 디바이스 인덱스 오류 시
ffmpeg -f avfoundation -list_devices true -i "" 2>&1
# 출력에서 올바른 스크린 인덱스 확인
```

## Chrome 창 정보 가져오기 (AppleScript)

```bash
# Chrome 창 위치/크기 확인
osascript -e 'tell application "Google Chrome"
  set bounds of front window to {0, 0, 1280, 800}
  get bounds of front window
end tell'
```

## 예시 워크플로우

```bash
# 1. Chrome 창 설정
osascript -e 'tell app "Google Chrome" to set bounds of front window to {0, 0, 1280, 800}'

# 2. 녹화 시작
ffmpeg -f avfoundation -framerate 30 -capture_cursor 1 \
  -i "1:none" -c:v libx264 -preset ultrafast -crf 18 \
  output/manual_recording.mp4 &
echo $! > /tmp/recording.pid

# 3. 시나리오 실행 (Chrome DevTools MCP 사용)
# ... 클릭, 입력 등 ...

# 4. 녹화 종료
kill -INT $(cat /tmp/recording.pid)
```
